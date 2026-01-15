require 'dry/monads'
require 'dry/monads/do'

module FunctionalTaskSupervisor
  class Task
    include Dry::Monads[:result, :do]

    attr_reader :results, :current_stage_index, :executed_stages

    def initialize
      @results = []
      @executed_stages = []
      @current_stage_index = 0
    end

    # Override in subclasses to define the sequence of stage classes
    def stage_klass_sequence
      raise NotImplementedError, 'Subclasses must implement the stage_klass_sequence method'
    end

    # Run all stages in sequence
    def run
      @results = []
      @executed_stages = []
      @current_stage_index = 0

      stage_klass_sequence.each_with_index do |stage_klass, index|
        @current_stage_index = index
        stage = stage_klass.new(task: self)
        @executed_stages << stage
        stage_result = execute_stage(stage)
        @results << stage_result
        yield stage_result  # Unwraps Success or halts on Failure
      end

      Success(
        results: @results,
        completed: @executed_stages.map(&:name),
        total_stages: stage_klass_sequence.length
      )
    end

    # Run stages with conditional execution
    def run_conditional
      @results = []
      @executed_stages = []
      @current_stage_index = 0

      while @current_stage_index < stage_klass_sequence.length
        stage = stage_klass_sequence[@current_stage_index].new(task: self)
        @executed_stages << stage
        stage_result = execute_stage(stage)
        @results << stage_result
        unwrapped = yield stage_result  # Unwraps Success or halts on Failure

        # Determine next stage based on result
        next_index = determine_next_stage(unwrapped, @current_stage_index)

        if next_index.nil?
          # No more stages to execute
          break
        end

        @current_stage_index = next_index
      end

      Success(
        results: @results,
        final_stage: @executed_stages.last&.name,
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

    # Reset task state
    def reset!
      @executed_stages.each(&:reset!)
      @executed_stages = []
      @results = []
      @current_stage_index = 0
    end

    private

    # Execute a single stage
    def execute_stage(stage)
      stage.execute
      stage.result
    end

    # Determine the next stage to execute (override in subclasses)
    def determine_next_stage(result, current_index)
      # Default: proceed to next stage sequentially
      next_index = current_index + 1
      next_index < stage_klass_sequence.length ? next_index : nil
    end
  end
end
