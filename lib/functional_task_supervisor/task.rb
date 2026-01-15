require 'dry/monads'
require 'dry/monads/do'

module FunctionalTaskSupervisor
  class Task
    include Dry::Monads[:result, :do]

    attr_reader :results, :current_stage_index

    def initialize
      @results = []
      @current_stage_index = 0
    end

    # Add a stage to the task
    def stages
      Failure('Subclasses must implement the stages method')
    end

    # Run all stages in sequence
    def run
      @results = []
      @current_stage_index = 0

      stage_klass_sequence.each_with_index do |stage_klass, index|
        @current_stage_index = index
        stage = stage_klass.new(task: self)
        stage_result = yield execute_stage(stage)
        @results << stage_result
      end

      Success(
        results: @results,
        completed: stages.map(&:name),
        total_stages: stages.length
      )
    end

    # Run stages with conditional execution
    def run_conditional
      @results = []
      @current_stage_index = 0

      while @current_stage_index < stages.length
        stage = stage_klass_sequence[@current_stage_index].new(task: self)
        stage_result = yield execute_stage(stage)
        @results << stage_result

        # Determine next stage based on result
        next_index = determine_next_stage(stage_result, @current_stage_index)

        if next_index.nil?
          # No more stages to execute
          break
        end

        @current_stage_index = next_index
      end

      Success(
        results: @results,
        final_stage: stages[@current_stage_index].name,
        executed_stages: @results.length
      )
    end

    # Get all successful results
    def successful_results
      @results.select { |r| r.success? }
    end

    # Get all failed results
    def failed_results
      @results.select { |r| r.failure? }
    end

    # Check if all stages completed successfully
    def all_successful?
      @results.any? && @results.all?(&:success?)
    end

    # Check if any stage failed
    def any_failed?
      @results.any?(&:failure?)
    end

    # Reset all stages
    def reset!
      @stages.each(&:reset!)
      @results = []
      @current_stage_index = 0
    end

    private

    # Execute a single stage
    def execute_stage(stage_klass)
      stage.execute
      stage.result
    end

    # Determine the next stage to execute (override in subclasses)
    def determine_next_stage(result, current_index)
      # Default: proceed to next stage sequentially
      next_index = current_index + 1
      next_index < stages.length ? next_index : nil
    end
  end
end
