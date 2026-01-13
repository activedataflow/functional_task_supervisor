require 'spec_helper'

RSpec.describe 'Effects Integration' do
  describe 'State tracking' do
    let(:task_class) do
      Class.new(FunctionalTaskSupervisor::Task) do
        include FunctionalTaskSupervisor::Effects::StateHandler
      end
    end

    let(:task) { task_class.new }
    let(:stage1) { FunctionalTaskSupervisor::Stage.new('stage1') }
    let(:stage2) { FunctionalTaskSupervisor::Stage.new('stage2') }

    before do
      task.add_stage(stage1).add_stage(stage2)
    end

    it 'tracks stage execution history' do
      runner = FunctionalTaskSupervisor::Effects::StateTaskRunner.new
      result = runner.call(task)

      expect(result[:history]).to eq(['stage1', 'stage2'])
    end

    it 'tracks stage metadata' do
      runner = FunctionalTaskSupervisor::Effects::StateTaskRunner.new
      result = runner.call(task)

      metadata = result[:metadata]
      expect(metadata['stage1']).to include(index: 0, success: true)
      expect(metadata['stage2']).to include(index: 1, success: true)
      expect(metadata['stage1'][:timestamp]).to be_a(Time)
    end

    it 'returns successful result' do
      runner = FunctionalTaskSupervisor::Effects::StateTaskRunner.new
      result = runner.call(task)

      expect(result[:result]).to be_success
    end
  end

  describe 'Dependency injection' do
    let(:logger) { double('Logger', info: nil, error: nil, warn: nil, debug: nil) }
    let(:repository) { double('Repository') }
    let(:config) { { timeout: 30, retries: 3 } }

    let(:stage_class) do
      Class.new(FunctionalTaskSupervisor::Stage) do
        include FunctionalTaskSupervisor::Effects::ResolveHandler

        private

        def perform_work
          log('Executing stage')
          Dry::Monads::Success(data: 'completed', config: configuration)
        end
      end
    end

    let(:stage) { stage_class.new('test_stage') }
    let(:task) { FunctionalTaskSupervisor::Task.new.add_stage(stage) }

    it 'provides dependencies to stages' do
      provider = FunctionalTaskSupervisor::Effects::DependencyProvider.new(
        logger: logger,
        repository: repository,
        config: config
      )

      result = provider.call(task)

      expect(result).to be_success
      expect(logger).to have_received(:info).with('[test_stage] Executing stage')
    end

    it 'makes config accessible in stages' do
      provider = FunctionalTaskSupervisor::Effects::DependencyProvider.new(
        logger: logger,
        repository: repository,
        config: config
      )

      result = provider.call(task)
      value = result.value!
      stage_result = value[:results].first.value!

      expect(stage_result[:config]).to eq(config)
    end
  end

  describe 'Combined effects' do
    let(:logger) { double('Logger', info: nil, error: nil, warn: nil, debug: nil) }
    let(:repository) { double('Repository') }
    let(:config) { { max_retries: 3 } }

    let(:task_class) do
      Class.new(FunctionalTaskSupervisor::Task) do
        include FunctionalTaskSupervisor::Effects::StateHandler
      end
    end

    let(:stage_class) do
      Class.new(FunctionalTaskSupervisor::Stage) do
        include FunctionalTaskSupervisor::Effects::ResolveHandler

        private

        def perform_work
          log('Processing stage')
          Dry::Monads::Success(data: 'done')
        end
      end
    end

    let(:task) { task_class.new }
    let(:stage1) { stage_class.new('stage1') }
    let(:stage2) { stage_class.new('stage2') }

    before do
      task.add_stage(stage1).add_stage(stage2)
    end

    it 'combines state tracking and dependency injection' do
      runner = FunctionalTaskSupervisor::Effects::TaskRunner.new(
        logger: logger,
        repository: repository,
        config: config
      )

      result = runner.call(task)

      expect(result[:history]).to eq(['stage1', 'stage2'])
      expect(result[:metadata]).to have_key('stage1')
      expect(result[:metadata]).to have_key('stage2')
      expect(result[:result]).to be_success
      expect(logger).to have_received(:info).twice
    end
  end

  describe 'Error handling with effects' do
    let(:logger) { double('Logger', info: nil, error: nil, warn: nil, debug: nil) }

    let(:failing_stage_class) do
      Class.new(FunctionalTaskSupervisor::Stage) do
        include FunctionalTaskSupervisor::Effects::ResolveHandler

        private

        def perform_work
          log('About to fail', level: :warn)
          Dry::Monads::Failure(error: 'Intentional failure')
        end
      end
    end

    let(:task_class) do
      Class.new(FunctionalTaskSupervisor::Task) do
        include FunctionalTaskSupervisor::Effects::StateHandler
      end
    end

    let(:task) { task_class.new }
    let(:stage) { failing_stage_class.new('failing_stage') }

    before do
      task.add_stage(stage)
    end

    it 'tracks failures in state' do
      runner = FunctionalTaskSupervisor::Effects::TaskRunner.new(logger: logger)
      result = runner.call(task)

      expect(result[:history]).to eq(['failing_stage'])
      expect(result[:metadata]['failing_stage'][:success]).to be false
      expect(result[:result]).to be_failure
    end

    it 'logs failure warnings' do
      runner = FunctionalTaskSupervisor::Effects::TaskRunner.new(logger: logger)
      runner.call(task)

      expect(logger).to have_received(:warn).with('[failing_stage] About to fail')
    end
  end
end
