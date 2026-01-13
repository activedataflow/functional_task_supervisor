require 'dry/effects'

module FunctionalTaskSupervisor
  module Effects
    # StateHandler provides state management for tasks
    # Usage:
    #   class MyTask < FunctionalTaskSupervisor::Task
    #     include FunctionalTaskSupervisor::Effects::StateHandler
    #   end
    module StateHandler
      def self.included(base)
        base.class_eval do
          include Dry::Monads[:result, :do]
          include Dry::Effects.State(:stage_history)
          include Dry::Effects.State(:stage_metadata)
        end
      end

      # Run task with state tracking
      def run_with_state
        @results = []
        @current_stage_index = 0

        # Initialize state
        self.stage_history = [] if stage_history.nil? || stage_history.empty?
        self.stage_metadata = {} if stage_metadata.nil? || stage_metadata.empty?

        stages.each_with_index do |stage, index|
          @current_stage_index = index
          
          # Track stage execution
          self.stage_history += [stage.name]
          
          # Execute stage
          stage_result = yield execute_stage(stage)
          @results << stage_result

          # Store metadata
          metadata = stage_metadata.dup
          metadata[stage.name] = {
            index: index,
            success: stage_result.success?,
            timestamp: Time.now
          }
          self.stage_metadata = metadata
        end

        Success(
          results: @results,
          completed: stages.map(&:name),
          history: stage_history,
          metadata: stage_metadata
        )
      end
    end

    # Handler class for wrapping task execution with state
    class StateTaskRunner
      include Dry::Effects::Handler.State(:stage_history)
      include Dry::Effects::Handler.State(:stage_metadata)

      def call(task)
        history, (metadata, result) = with_stage_history([]) do
          with_stage_metadata({}) do
            task.run_with_state
          end
        end

        {
          history: history,
          metadata: metadata,
          result: result
        }
      end
    end
  end
end
