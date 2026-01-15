require 'dry/monads'

module FunctionalTaskSupervisor
  class Stage
    include Dry::Monads[:result]

    attr_reader :name, :task, :result

    def initialize(task:, name: self.class.name.downcase)
      @task = task
      @name = name
      @result = nil  # Not run yet
    end

    # Execute the stage and store the result
    def execute
      @result = validate_preconditions.bind do
        perform_work
      end.or do |failure|
        handle_failure(failure)
      end
    rescue StandardError => e
      @result = Failure(
        error: e.message,
        stage: @name,
        backtrace: e.backtrace.first(5),
        timestamp: Time.now
      )
    end

    # Check if stage has been executed
    def performed?
      !@result.nil?
    end

    # Check if stage execution was successful
    def success?
      performed? && @result.success?
    end

    # Check if stage execution failed
    def failure?
      performed? && @result.failure?
    end

    # Get the value from a successful result
    def value
      return nil unless success?
      @result.value!
    end

    # Get the error from a failed result
    def error
      return nil unless failure?
      @result.failure
    end

    # Reset the stage to unexecuted state
    def reset!
      @result = nil
    end

    private

    # Override in subclasses to validate preconditions
    def validate_preconditions
      if preconditions_met?
        Success(:ready)
      else
        Failure(error: "Preconditions not met", stage: @name)
      end
    end

    # Override in subclasses to implement stage logic
    def perform_work
      Success(data: "completed", stage: @name)
    end

    # Override in subclasses to handle failures
    def handle_failure(failure)
      if recoverable?(failure)
        retry_with_backoff
      else
        Failure(failure)
      end
    end

    # Override in subclasses to check preconditions
    def preconditions_met?
      true
    end

    # Override in subclasses to determine if failure is recoverable
    def recoverable?(failure)
      false
    end

    # Override in subclasses to implement retry logic
    def retry_with_backoff
      Failure(error: "Retry not implemented", stage: @name)
    end
  end
end
