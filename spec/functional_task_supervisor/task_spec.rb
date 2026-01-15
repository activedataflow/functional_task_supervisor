require 'spec_helper'

RSpec.describe FunctionalTaskSupervisor::Task do
  # Define stage classes for testing
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

  let(:stage3_class) do
    Class.new(FunctionalTaskSupervisor::Stage) do
      def self.name
        'Stage3'
      end
    end
  end

  # Create a test task class with configurable stages
  let(:test_task_class) do
    stages = [stage1_class, stage2_class, stage3_class]
    Class.new(described_class) do
      define_method(:stage_klass_sequence) { stages }
    end
  end

  let(:task) { test_task_class.new }

  describe '#initialize' do
    it 'creates a task with empty results' do
      expect(task.results).to be_empty
    end

    it 'creates a task with empty executed_stages' do
      expect(task.executed_stages).to be_empty
    end

    it 'initializes current_stage_index to 0' do
      expect(task.current_stage_index).to eq(0)
    end
  end

  describe '#stage_klass_sequence' do
    it 'raises NotImplementedError when not overridden' do
      base_task = described_class.new
      expect { base_task.stage_klass_sequence }.to raise_error(NotImplementedError)
    end

    it 'returns stage classes when properly implemented' do
      expect(task.stage_klass_sequence).to eq([stage1_class, stage2_class, stage3_class])
    end
  end

  describe '#run' do
    it 'executes all stages' do
      result = task.run
      expect(result).to be_success
    end

    it 'stores results for all stages' do
      task.run
      expect(task.results.length).to eq(3)
    end

    it 'tracks executed stages' do
      task.run
      expect(task.executed_stages.length).to eq(3)
    end

    it 'returns a Success with completed stages' do
      result = task.run
      expect(result.value![:completed]).to eq(['stage1', 'stage2', 'stage3'])
    end

    it 'returns total stages count' do
      result = task.run
      expect(result.value![:total_stages]).to eq(3)
    end

    it 'marks all executed stages as performed' do
      task.run
      expect(task.executed_stages.all?(&:performed?)).to be true
    end

    context 'when a stage fails' do
      let(:failing_stage_class) do
        Class.new(FunctionalTaskSupervisor::Stage) do
          def self.name
            'FailingStage'
          end

          private

          def perform_work
            Dry::Monads::Failure(error: 'Stage failed')
          end
        end
      end

      let(:task_with_failure_class) do
        stages = [stage1_class, stage2_class, stage3_class, failing_stage_class]
        Class.new(described_class) do
          define_method(:stage_klass_sequence) { stages }
        end
      end

      let(:failing_task) { task_with_failure_class.new }

      it 'stops execution and returns failure' do
        result = failing_task.run
        expect(result).to be_failure
      end

      it 'includes the failure in results' do
        failing_task.run
        expect(failing_task.results.last).to be_failure
      end
    end
  end

  describe '#run_conditional' do
    it 'executes stages conditionally' do
      result = task.run_conditional
      expect(result).to be_success
    end

    it 'returns executed stages count' do
      result = task.run_conditional
      expect(result.value![:executed_stages]).to eq(3)
    end

    it 'returns the final stage name' do
      result = task.run_conditional
      expect(result.value![:final_stage]).to eq('stage3')
    end

    context 'with custom next stage logic' do
      let(:custom_task_class) do
        stages = [stage1_class, stage2_class, stage3_class]
        Class.new(described_class) do
          define_method(:stage_klass_sequence) { stages }

          private

          def determine_next_stage(result, current_index)
            # Skip stage2 (index 1)
            next_index = current_index + 1
            next_index = next_index + 1 if next_index == 1
            next_index < stage_klass_sequence.length ? next_index : nil
          end
        end
      end

      let(:custom_task) { custom_task_class.new }

      it 'follows custom stage execution logic' do
        result = custom_task.run_conditional
        expect(result).to be_success
        expect(custom_task.results.length).to eq(2)
      end
    end
  end

  describe '#successful_results' do
    let(:two_stage_task_class) do
      stages = [stage1_class, stage2_class]
      Class.new(described_class) do
        define_method(:stage_klass_sequence) { stages }
      end
    end

    let(:two_stage_task) { two_stage_task_class.new }

    it 'returns only successful results' do
      two_stage_task.run
      expect(two_stage_task.successful_results.length).to eq(2)
    end

    context 'with mixed results' do
      let(:failing_stage_class) do
        Class.new(FunctionalTaskSupervisor::Stage) do
          def self.name
            'FailingStage'
          end

          private

          def perform_work
            Dry::Monads::Failure(error: 'Failed')
          end
        end
      end

      let(:mixed_task_class) do
        stages = [stage1_class, stage2_class, failing_stage_class]
        Class.new(described_class) do
          define_method(:stage_klass_sequence) { stages }
        end
      end

      let(:mixed_task) { mixed_task_class.new }

      it 'filters out failed results' do
        mixed_task.run rescue nil
        successful = mixed_task.successful_results
        expect(successful.all?(&:success?)).to be true
      end
    end
  end

  describe '#failed_results' do
    let(:failing_stage_class) do
      Class.new(FunctionalTaskSupervisor::Stage) do
        def self.name
          'FailingStage'
        end

        private

        def perform_work
          Dry::Monads::Failure(error: 'Failed')
        end
      end
    end

    let(:task_with_failure_class) do
      stages = [stage1_class, failing_stage_class]
      Class.new(described_class) do
        define_method(:stage_klass_sequence) { stages }
      end
    end

    let(:failing_task) { task_with_failure_class.new }

    it 'returns only failed results' do
      failing_task.run rescue nil
      failed = failing_task.failed_results
      expect(failed.all?(&:failure?)).to be true
    end
  end

  describe '#all_successful?' do
    let(:two_stage_task_class) do
      stages = [stage1_class, stage2_class]
      Class.new(described_class) do
        define_method(:stage_klass_sequence) { stages }
      end
    end

    let(:two_stage_task) { two_stage_task_class.new }

    it 'returns true when all stages succeed' do
      two_stage_task.run
      expect(two_stage_task.all_successful?).to be true
    end

    it 'returns false when any stage fails' do
      failing_stage_class = Class.new(FunctionalTaskSupervisor::Stage) do
        def self.name
          'FailingStage'
        end

        private

        def perform_work
          Dry::Monads::Failure(error: 'Failed')
        end
      end

      task_class = Class.new(described_class) do
        define_method(:stage_klass_sequence) { [FunctionalTaskSupervisor::Stage, failing_stage_class] }
      end

      failing_task = task_class.new
      failing_task.run rescue nil
      expect(failing_task.all_successful?).to be false
    end
  end

  describe '#any_failed?' do
    let(:two_stage_task_class) do
      stages = [stage1_class, stage2_class]
      Class.new(described_class) do
        define_method(:stage_klass_sequence) { stages }
      end
    end

    let(:two_stage_task) { two_stage_task_class.new }

    it 'returns false when all stages succeed' do
      two_stage_task.run
      expect(two_stage_task.any_failed?).to be false
    end

    it 'returns true when any stage fails' do
      failing_stage_class = Class.new(FunctionalTaskSupervisor::Stage) do
        def self.name
          'FailingStage'
        end

        private

        def perform_work
          Dry::Monads::Failure(error: 'Failed')
        end
      end

      task_class = Class.new(described_class) do
        define_method(:stage_klass_sequence) { [FunctionalTaskSupervisor::Stage, failing_stage_class] }
      end

      failing_task = task_class.new
      failing_task.run rescue nil
      expect(failing_task.any_failed?).to be true
    end
  end

  describe '#reset!' do
    let(:two_stage_task_class) do
      stages = [stage1_class, stage2_class]
      Class.new(described_class) do
        define_method(:stage_klass_sequence) { stages }
      end
    end

    let(:reset_task) { two_stage_task_class.new }

    before do
      reset_task.run
    end

    it 'resets all executed stages' do
      reset_task.reset!
      expect(reset_task.executed_stages).to be_empty
    end

    it 'clears results' do
      reset_task.reset!
      expect(reset_task.results).to be_empty
    end

    it 'resets current_stage_index' do
      reset_task.reset!
      expect(reset_task.current_stage_index).to eq(0)
    end
  end
end
