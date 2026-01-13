require 'dry/effects'

module FunctionalTaskSupervisor
  module Effects
    # ResolveHandler provides dependency injection for stages
    # Usage:
    #   class MyStage < FunctionalTaskSupervisor::Stage
    #     include FunctionalTaskSupervisor::Effects::ResolveHandler
    #   end
    module ResolveHandler
      def self.included(base)
        base.class_eval do
          include Dry::Effects.Resolve(:logger, :repository, :config)
        end
      end

      # Access logger (will be provided by handler)
      def log(message, level: :info)
        return unless respond_to?(:logger)
        logger.send(level, "[#{name}] #{message}")
      end

      # Access repository (will be provided by handler)
      def repo
        repository if respond_to?(:repository)
      end

      # Access config (will be provided by handler)
      def configuration
        config if respond_to?(:config)
      end
    end

    # Handler class for providing dependencies to stages
    class DependencyProvider
      include Dry::Effects::Handler.Resolve

      attr_reader :logger, :repository, :config

      def initialize(logger: nil, repository: nil, config: {})
        @logger = logger || default_logger
        @repository = repository
        @config = config
      end

      def call(task)
        provide(logger: @logger, repository: @repository, config: @config) do
          task.run
        end
      end

      private

      def default_logger
        require 'logger'
        Logger.new($stdout)
      end
    end

    # Combined handler for both state and dependencies
    class TaskRunner
      include Dry::Effects::Handler.State(:stage_history)
      include Dry::Effects::Handler.State(:stage_metadata)
      include Dry::Effects::Handler.Resolve

      attr_reader :logger, :repository, :config

      def initialize(logger: nil, repository: nil, config: {})
        @logger = logger || default_logger
        @repository = repository
        @config = config
      end

      def call(task)
        history, (metadata, result) = with_stage_history([]) do
          with_stage_metadata({}) do
            provide(logger: @logger, repository: @repository, config: @config) do
              if task.respond_to?(:run_with_state)
                task.run_with_state
              else
                task.run
              end
            end
          end
        end

        {
          history: history,
          metadata: metadata,
          result: result
        }
      end

      private

      def default_logger
        require 'logger'
        Logger.new($stdout)
      end
    end
  end
end
