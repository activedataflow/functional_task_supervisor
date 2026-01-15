require 'spec_helper'

RSpec.describe FunctionalTaskSupervisor::Stage do
  let(:mock_task) { double('Task') }
  let(:stage) { described_class.new(task: mock_task, name: 'test_stage') }

  describe '#initialize' do
    it 'creates a stage with a name' do
      expect(stage.name).to eq('test_stage')
    end

    it 'stores reference to the task' do
      expect(stage.task).to eq(mock_task)
    end

    it 'initializes with nil result' do
      expect(stage.result).to be_nil
    end

    it 'defaults name to downcased class name' do
      stage = described_class.new(task: mock_task)
      expect(stage.name).to eq('functionaltasksupervisor::stage')
    end
  end

  describe '#execute' do
    it 'executes the stage and stores a Success result' do
      stage.execute
      expect(stage.result).to be_success
    end

    it 'marks the stage as performed' do
      stage.execute
      expect(stage.performed?).to be true
    end

    it 'returns a Success with stage data' do
      stage.execute
      expect(stage.value).to include(data: 'completed', stage: 'test_stage')
    end

    context 'when an exception occurs' do
      let(:failing_stage_class) do
        Class.new(described_class) do
          private

          def perform_work
            raise StandardError, 'Something went wrong'
          end
        end
      end
      let(:failing_stage) { failing_stage_class.new(task: mock_task, name: 'failing_stage') }

      it 'captures the exception in a Failure result' do
        failing_stage.execute
        expect(failing_stage.result).to be_failure
      end

      it 'includes error details in the failure' do
        failing_stage.execute
        error = failing_stage.error
        expect(error[:error]).to eq('Something went wrong')
        expect(error[:stage]).to eq('failing_stage')
        expect(error[:backtrace]).to be_an(Array)
        expect(error[:timestamp]).to be_a(Time)
      end
    end
  end

  describe '#performed?' do
    it 'returns false before execution' do
      expect(stage.performed?).to be false
    end

    it 'returns true after execution' do
      stage.execute
      expect(stage.performed?).to be true
    end
  end

  describe '#success?' do
    it 'returns false before execution' do
      expect(stage.success?).to be false
    end

    it 'returns true after successful execution' do
      stage.execute
      expect(stage.success?).to be true
    end

    it 'returns false after failed execution' do
      allow(stage).to receive(:perform_work).and_return(Dry::Monads::Failure('error'))
      stage.execute
      expect(stage.success?).to be false
    end
  end

  describe '#failure?' do
    it 'returns false before execution' do
      expect(stage.failure?).to be false
    end

    it 'returns false after successful execution' do
      stage.execute
      expect(stage.failure?).to be false
    end

    it 'returns true after failed execution' do
      allow(stage).to receive(:perform_work).and_return(Dry::Monads::Failure('error'))
      stage.execute
      expect(stage.failure?).to be true
    end
  end

  describe '#value' do
    it 'returns nil before execution' do
      expect(stage.value).to be_nil
    end

    it 'returns the value after successful execution' do
      stage.execute
      expect(stage.value).to include(data: 'completed')
    end

    it 'returns nil after failed execution' do
      allow(stage).to receive(:perform_work).and_return(Dry::Monads::Failure('error'))
      stage.execute
      expect(stage.value).to be_nil
    end
  end

  describe '#error' do
    it 'returns nil before execution' do
      expect(stage.error).to be_nil
    end

    it 'returns nil after successful execution' do
      stage.execute
      expect(stage.error).to be_nil
    end

    it 'returns the error after failed execution' do
      allow(stage).to receive(:perform_work).and_return(Dry::Monads::Failure('test error'))
      stage.execute
      expect(stage.error).to eq('test error')
    end
  end

  describe '#reset!' do
    it 'resets the stage to unexecuted state' do
      stage.execute
      expect(stage.performed?).to be true

      stage.reset!
      expect(stage.performed?).to be false
      expect(stage.result).to be_nil
    end
  end

  describe 'custom stage implementation' do
    let(:custom_stage_class) do
      Class.new(described_class) do
        private

        def perform_work
          Dry::Monads::Success(custom_data: 'custom value')
        end
      end
    end
    let(:custom_stage) { custom_stage_class.new(task: mock_task, name: 'custom_stage') }

    it 'allows overriding perform_work' do
      custom_stage.execute
      expect(custom_stage.value).to eq(custom_data: 'custom value')
    end
  end

  describe 'preconditions' do
    let(:conditional_stage_class) do
      Class.new(described_class) do
        attr_accessor :condition_met

        def initialize(task:, name: self.class.name.downcase)
          super
          @condition_met = true
        end

        private

        def preconditions_met?
          @condition_met
        end
      end
    end
    let(:conditional_stage) { conditional_stage_class.new(task: mock_task, name: 'conditional_stage') }

    it 'executes when preconditions are met' do
      conditional_stage.condition_met = true
      conditional_stage.execute
      expect(conditional_stage.success?).to be true
    end

    it 'fails when preconditions are not met' do
      conditional_stage.condition_met = false
      conditional_stage.execute
      expect(conditional_stage.failure?).to be true
      expect(conditional_stage.error[:error]).to eq('Preconditions not met')
    end
  end
end
