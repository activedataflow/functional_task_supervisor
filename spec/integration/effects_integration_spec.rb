require 'spec_helper'

RSpec.describe 'Effects Integration' do
  # Define reusable stage classes
  let(:simple_stage_class) do
    Class.new(FunctionalTaskSupervisor::Stage) do
      def self.name
        'SimpleStage'
      end
    end
  end

  describe 'State tracking' do
    let(:stage1_class) do
      Class.new(FunctionalTaskSupervisor::Stage) do
        def self.name
          'Stage1'
        end
      end
    end

    let(:stage2_class) do
      Class.new(FunctionalTaskSupervisor::Stage) do
        def self.name
          'Stage2'
        end
      end
    end

    let(:task_class) do
      s1 = stage1_class
      s2 = stage2_class
      Class.new(FunctionalTaskSupervisor::Task) do
        include FunctionalTaskSupervisor::Effects::StateHandler

        define_method(:stage_klass_sequence) { [s1, s2] }
      end
    end

    let(:task) { task_class.new }

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

    let(:logging_stage_class) do
      Class.new(FunctionalTaskSupervisor::Stage) do
        include FunctionalTaskSupervisor::Effects::ResolveHandler

        def self.name
          'TestStage'
        end

        private

        def perform_work
          log('Executing stage')
          Dry::Monads::Success(data: 'completed', config: configuration)
        end
      end
    end

    let(:task_class) do
      stage_klass = logging_stage_class
      Class.new(FunctionalTaskSupervisor::Task) do
        define_method(:stage_klass_sequence) { [stage_klass] }
      end
    end

    let(:task) { task_class.new }

    it 'provides dependencies to stages' do
      provider = FunctionalTaskSupervisor::Effects::DependencyProvider.new(
        logger: logger,
        repository: repository,
        config: config
      )

      result = provider.call(task)

      expect(result).to be_success
      expect(logger).to have_received(:info).with('[teststage] Executing stage')
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

    let(:advanced_stage_class) do
      Class.new(FunctionalTaskSupervisor::Stage) do
        include FunctionalTaskSupervisor::Effects::ResolveHandler

        def self.name
          'AdvancedStage'
        end

        private

        def perform_work
          log('Processing stage')
          Dry::Monads::Success(data: 'done')
        end
      end
    end

    let(:stage1_class) do
      Class.new(advanced_stage_class) do
        def self.name
          'Stage1'
        end
      end
    end

    let(:stage2_class) do
      Class.new(advanced_stage_class) do
        def self.name
          'Stage2'
        end
      end
    end

    let(:task_class) do
      s1 = stage1_class
      s2 = stage2_class
      Class.new(FunctionalTaskSupervisor::Task) do
        include FunctionalTaskSupervisor::Effects::StateHandler

        define_method(:stage_klass_sequence) { [s1, s2] }
      end
    end

    let(:task) { task_class.new }

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

        def self.name
          'FailingStage'
        end

        private

        def perform_work
          log('About to fail', level: :warn)
          Dry::Monads::Failure(error: 'Intentional failure')
        end
      end
    end

    let(:task_class) do
      stage_klass = failing_stage_class
      Class.new(FunctionalTaskSupervisor::Task) do
        include FunctionalTaskSupervisor::Effects::StateHandler

        define_method(:stage_klass_sequence) { [stage_klass] }
      end
    end

    let(:task) { task_class.new }

    it 'tracks failures in state' do
      runner = FunctionalTaskSupervisor::Effects::TaskRunner.new(logger: logger)
      result = runner.call(task)

      expect(result[:history]).to eq(['failingstage'])
      expect(result[:metadata]['failingstage'][:success]).to be false
      expect(result[:result]).to be_failure
    end

    it 'logs failure warnings' do
      runner = FunctionalTaskSupervisor::Effects::TaskRunner.new(logger: logger)
      runner.call(task)

      expect(logger).to have_received(:warn).with('[failingstage] About to fail')
    end
  end
end
