#!/usr/bin/env ruby

require 'bundler/setup'
require 'functional_task_supervisor'
require 'logger'

# Example 1: State Tracking
puts "=" * 60
puts "Example 1: State Tracking with Effects"
puts "=" * 60

class SimpleStage < FunctionalTaskSupervisor::Stage
  private

  def perform_work
    puts "  [#{name}] Executing..."
    sleep(0.3)
    Success(data: "completed #{name}")
  end
end

class Stage1 < SimpleStage; end
class Stage2 < SimpleStage; end
class Stage3 < SimpleStage; end

class TaskWithState < FunctionalTaskSupervisor::Task
  include FunctionalTaskSupervisor::Effects::StateHandler

  def stage_klass_sequence
    [Stage1, Stage2, Stage3]
  end
end

task1 = TaskWithState.new
runner = FunctionalTaskSupervisor::Effects::StateTaskRunner.new
result = runner.call(task1)

puts "\n✓ Task completed with state tracking!"
puts "  Execution history: #{result[:history].join(' → ')}"
puts "  Metadata:"
result[:metadata].each do |stage_name, meta|
  puts "    #{stage_name}: index=#{meta[:index]}, success=#{meta[:success]}, time=#{meta[:timestamp].strftime('%H:%M:%S')}"
end

# Example 2: Dependency Injection
puts "\n" + "=" * 60
puts "Example 2: Dependency Injection with Effects"
puts "=" * 60

class LoggingStage < FunctionalTaskSupervisor::Stage
  include FunctionalTaskSupervisor::Effects::ResolveHandler

  private

  def perform_work
    log('Starting stage execution')
    sleep(0.3)
    log('Stage execution completed', level: :info)
    Success(data: "logged #{name}")
  end
end

class LoggingStage1 < LoggingStage; end
class LoggingStage2 < LoggingStage; end

class TaskWithLogging < FunctionalTaskSupervisor::Task
  def stage_klass_sequence
    [LoggingStage1, LoggingStage2]
  end
end

logger = Logger.new($stdout)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "  [LOG] #{severity}: #{msg}\n"
end

task2 = TaskWithLogging.new
provider = FunctionalTaskSupervisor::Effects::DependencyProvider.new(logger: logger)
result2 = provider.call(task2)

puts "\n✓ Task completed with dependency injection!"

# Example 3: Combined Effects
puts "\n" + "=" * 60
puts "Example 3: Combined State Tracking and Dependency Injection"
puts "=" * 60

class AdvancedStage < FunctionalTaskSupervisor::Stage
  include FunctionalTaskSupervisor::Effects::ResolveHandler

  private

  def perform_work
    log("Processing #{name}")
    sleep(0.3)

    # Simulate some work
    result_data = { processed: true, timestamp: Time.now }

    log("Completed #{name}", level: :info)
    Success(data: result_data)
  end
end

class Advanced1 < AdvancedStage; end
class Advanced2 < AdvancedStage; end
class Advanced3 < AdvancedStage; end

class TaskWithBothEffects < FunctionalTaskSupervisor::Task
  include FunctionalTaskSupervisor::Effects::StateHandler

  def stage_klass_sequence
    [Advanced1, Advanced2, Advanced3]
  end
end

task3 = TaskWithBothEffects.new
combined_runner = FunctionalTaskSupervisor::Effects::TaskRunner.new(
  logger: logger,
  config: { timeout: 30, retries: 3 }
)

result3 = combined_runner.call(task3)

puts "\n✓ Task completed with combined effects!"
puts "  History: #{result3[:history].join(' → ')}"
puts "  Metadata entries: #{result3[:metadata].keys.length}"
puts "  Result: #{result3[:result].success? ? 'SUCCESS' : 'FAILURE'}"

# Example 4: Error Handling with Effects
puts "\n" + "=" * 60
puts "Example 4: Error Handling with Effects"
puts "=" * 60

class FailingStageWithLogging < FunctionalTaskSupervisor::Stage
  include FunctionalTaskSupervisor::Effects::ResolveHandler

  private

  def perform_work
    log('Attempting risky operation', level: :warn)
    sleep(0.3)
    log('Operation failed!', level: :error)
    Failure(error: 'Intentional failure for demonstration', stage: name)
  end
end

class BeforeFailure < AdvancedStage; end
class AfterFailure < AdvancedStage; end

class TaskWithFailure < FunctionalTaskSupervisor::Task
  include FunctionalTaskSupervisor::Effects::StateHandler

  def stage_klass_sequence
    [BeforeFailure, FailingStageWithLogging, AfterFailure]
  end
end

task4 = TaskWithFailure.new
result4 = combined_runner.call(task4)

puts "\n✗ Task failed as expected!"
puts "  History: #{result4[:history].join(' → ')}"
puts "  Metadata:"
result4[:metadata].each do |stage_name, meta|
  status = meta[:success] ? '✓' : '✗'
  puts "    #{status} #{stage_name}: success=#{meta[:success]}"
end
puts "  Error: #{result4[:result].failure[:error]}"

# Example 5: Custom Repository with Dependency Injection
puts "\n" + "=" * 60
puts "Example 5: Custom Repository with Dependency Injection"
puts "=" * 60

class MockRepository
  def initialize
    @data = {}
  end

  def save(key, value)
    @data[key] = value
    puts "  [REPO] Saved: #{key} = #{value}"
  end

  def fetch(key)
    value = @data[key]
    puts "  [REPO] Fetched: #{key} = #{value}"
    value
  end
end

class RepositoryStage < FunctionalTaskSupervisor::Stage
  include FunctionalTaskSupervisor::Effects::ResolveHandler

  private

  def perform_work
    log("Using repository in #{name}")

    # Use injected repository
    repo.save(name, "data_#{name}")
    fetched = repo.fetch(name)

    Success(data: fetched)
  end
end

class RepoStage1 < RepositoryStage; end
class RepoStage2 < RepositoryStage; end

class TaskWithRepository < FunctionalTaskSupervisor::Task
  def stage_klass_sequence
    [RepoStage1, RepoStage2]
  end
end

repository = MockRepository.new
task5 = TaskWithRepository.new
repo_provider = FunctionalTaskSupervisor::Effects::DependencyProvider.new(
  logger: logger,
  repository: repository
)

result5 = repo_provider.call(task5)

puts "\n✓ Task completed with repository injection!"
puts "  All stages used the same repository instance"

puts "\n" + "=" * 60
puts "Effects examples completed!"
puts "=" * 60
