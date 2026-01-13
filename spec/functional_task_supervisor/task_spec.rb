require 'spec_helper'

RSpec.describe FunctionalTaskSupervisor::Task do
  let(:task) { described_class.new }
  let(:stage1) { FunctionalTaskSupervisor::Stage.new('stage1') }
  let(:stage2) { FunctionalTaskSupervisor::Stage.new('stage2') }
  let(:stage3) { FunctionalTaskSupervisor::Stage.new('stage3') }

  describe '#initialize' do
    it 'creates a task with empty stages' do
      expect(task.stages).to be_empty
    end

    it 'creates a task with empty results' do
      expect(task.results).to be_empty
    end

    it 'initializes current_stage_index to 0' do
      expect(task.current_stage_index).to eq(0)
    end
  end

  describe '#add_stage' do
    it 'adds a stage to the task' do
      task.add_stage(stage1)
      expect(task.stages).to include(stage1)
    end

    it 'returns self for chaining' do
      expect(task.add_stage(stage1)).to eq(task)
    end

    it 'allows chaining multiple stages' do
      task.add_stage(stage1).add_stage(stage2).add_stage(stage3)
      expect(task.stages.length).to eq(3)
    end
  end

  describe '#run' do
    before do
      task.add_stage(stage1).add_stage(stage2).add_stage(stage3)
    end

    it 'executes all stages' do
      result = task.run
      expect(result).to be_success
    end

    it 'stores results for all stages' do
      task.run
      expect(task.results.length).to eq(3)
    end

    it 'returns a Success with completed stages' do
      result = task.run
      expect(result.value![:completed]).to eq(['stage1', 'stage2', 'stage3'])
    end

    it 'returns total stages count' do
      result = task.run
      expect(result.value![:total_stages]).to eq(3)
    end

    it 'marks all stages as performed' do
      task.run
      expect(stage1.performed?).to be true
      expect(stage2.performed?).to be true
      expect(stage3.performed?).to be true
    end

    context 'when a stage fails' do
      let(:failing_stage) do
        Class.new(FunctionalTaskSupervisor::Stage) do
          private

          def perform_work
            Dry::Monads::Failure(error: 'Stage failed')
          end
        end.new('failing_stage')
      end

      before do
        task.add_stage(failing_stage)
      end

      it 'stops execution and returns failure' do
        result = task.run
        expect(result).to be_failure
      end

      it 'includes the failure in results' do
        task.run
        expect(task.results.last).to be_failure
      end
    end
  end

  describe '#run_conditional' do
    before do
      task.add_stage(stage1).add_stage(stage2).add_stage(stage3)
    end

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
      let(:custom_task) do
        Class.new(described_class) do
          private

          def determine_next_stage(result, current_index)
            # Skip stage2 (index 1)
            next_index = current_index + 1
            next_index = next_index + 1 if next_index == 1
            next_index < stages.length ? next_index : nil
          end
        end.new
      end

      before do
        custom_task.add_stage(stage1).add_stage(stage2).add_stage(stage3)
      end

      it 'follows custom stage execution logic' do
        result = custom_task.run_conditional
        expect(result).to be_success
        expect(custom_task.results.length).to eq(2)
        expect(stage2.performed?).to be false
      end
    end
  end

  describe '#successful_results' do
    before do
      task.add_stage(stage1).add_stage(stage2)
    end

    it 'returns only successful results' do
      task.run
      expect(task.successful_results.length).to eq(2)
    end

    context 'with mixed results' do
      let(:failing_stage) do
        Class.new(FunctionalTaskSupervisor::Stage) do
          private

          def perform_work
            Dry::Monads::Failure(error: 'Failed')
          end
        end.new('failing')
      end

      before do
        task.add_stage(failing_stage)
      end

      it 'filters out failed results' do
        task.run rescue nil
        successful = task.successful_results
        expect(successful.all?(&:success?)).to be true
      end
    end
  end

  describe '#failed_results' do
    let(:failing_stage) do
      Class.new(FunctionalTaskSupervisor::Stage) do
        private

        def perform_work
          Dry::Monads::Failure(error: 'Failed')
        end
      end.new('failing')
    end

    before do
      task.add_stage(stage1).add_stage(failing_stage)
    end

    it 'returns only failed results' do
      task.run rescue nil
      failed = task.failed_results
      expect(failed.all?(&:failure?)).to be true
    end
  end

  describe '#all_successful?' do
    before do
      task.add_stage(stage1).add_stage(stage2)
    end

    it 'returns true when all stages succeed' do
      task.run
      expect(task.all_successful?).to be true
    end

    it 'returns false when any stage fails' do
      failing_stage = Class.new(FunctionalTaskSupervisor::Stage) do
        private

        def perform_work
          Dry::Monads::Failure(error: 'Failed')
        end
      end.new('failing')

      task.add_stage(failing_stage)
      task.run rescue nil
      expect(task.all_successful?).to be false
    end
  end

  describe '#any_failed?' do
    before do
      task.add_stage(stage1).add_stage(stage2)
    end

    it 'returns false when all stages succeed' do
      task.run
      expect(task.any_failed?).to be false
    end

    it 'returns true when any stage fails' do
      failing_stage = Class.new(FunctionalTaskSupervisor::Stage) do
        private

        def perform_work
          Dry::Monads::Failure(error: 'Failed')
        end
      end.new('failing')

      task.add_stage(failing_stage)
      task.run rescue nil
      expect(task.any_failed?).to be true
    end
  end

  describe '#reset!' do
    before do
      task.add_stage(stage1).add_stage(stage2)
      task.run
    end

    it 'resets all stages' do
      task.reset!
      expect(stage1.performed?).to be false
      expect(stage2.performed?).to be false
    end

    it 'clears results' do
      task.reset!
      expect(task.results).to be_empty
    end

    it 'resets current_stage_index' do
      task.reset!
      expect(task.current_stage_index).to eq(0)
    end
  end
end
