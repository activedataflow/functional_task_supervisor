# FunctionalTaskSupervisor

A Ruby gem that implements multi-stage task lifecycle using **dry-monads** Result types and **dry-effects** for composable, testable task execution.

## Features

- **Type-safe error handling** with dry-monads Result types (Success/Failure)
- **Multi-stage task lifecycle** with explicit stage states (nil/Success/Failure)
- **Composable effects** using dry-effects for state management and dependency injection
- **Clean syntax** with Do notation for readable monadic composition
- **Transaction safety** through exception-based control flow
- **Comprehensive testing** with RSpec and Cucumber

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'functional_task_supervisor'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install functional_task_supervisor
```

## Quick Start

### Basic Usage

```ruby
require 'functional_task_supervisor'

# Define custom stages
class FetchDataStage < FunctionalTaskSupervisor::Stage
  private

  def perform_work
    data = fetch_from_api
    Success(data: data)
  rescue StandardError => e
    Failure(error: e.message)
  end

  def fetch_from_api
    # Your API logic here
    { users: ['Alice', 'Bob'] }
  end
end

class ProcessDataStage < FunctionalTaskSupervisor::Stage
  private

  def perform_work
    processed = process_data
    Success(data: processed)
  end

  def process_data
    # Your processing logic here
    { processed: true }
  end
end

# Create and run task
task = FunctionalTaskSupervisor::Task.new
task.add_stage(FetchDataStage.new('fetch'))
task.add_stage(ProcessDataStage.new('process'))

result = task.run

case result
when Dry::Monads::Success
  puts "Task completed successfully!"
  puts "Completed stages: #{result.value![:completed]}"
when Dry::Monads::Failure
  puts "Task failed: #{result.failure[:error]}"
end
```

## Core Concepts

### Stage

A **Stage** represents a single unit of work with a Result (Success/Failure).

**Stage States:**
- `nil` - Stage has not been run yet
- `Success(data)` - Stage ran successfully
- `Failure(error)` - Stage failed

```ruby
stage = FunctionalTaskSupervisor::Stage.new('my_stage')

# Check stage state
stage.performed?  # => false
stage.success?    # => false
stage.failure?    # => false

# Execute stage
stage.execute

# Check results
stage.performed?  # => true
stage.success?    # => true
stage.value       # => { data: "completed", stage: "my_stage" }
```

### Task

A **Task** orchestrates the execution of multiple stages and determines the next stage to run.

```ruby
task = FunctionalTaskSupervisor::Task.new

# Add stages
task.add_stage(stage1)
    .add_stage(stage2)
    .add_stage(stage3)

# Run all stages
result = task.run

# Check results
task.all_successful?      # => true/false
task.any_failed?          # => true/false
task.successful_results   # => Array of Success results
task.failed_results       # => Array of Failure results
```

### Custom Stages

Create custom stages by subclassing `Stage` and overriding `perform_work`:

```ruby
class CustomStage < FunctionalTaskSupervisor::Stage
  private

  def perform_work
    # Your logic here
    if everything_ok?
      Success(data: 'custom result')
    else
      Failure(error: 'something went wrong')
    end
  end
end
```

### Preconditions

Stages can validate preconditions before execution:

```ruby
class ConditionalStage < FunctionalTaskSupervisor::Stage
  private

  def preconditions_met?
    # Check if stage can run
    some_condition == true
  end

  def perform_work
    Success(data: 'executed')
  end
end
```

## Effects Integration

### State Tracking

Track stage execution history and metadata using state effects:

```ruby
class MyTask < FunctionalTaskSupervisor::Task
  include FunctionalTaskSupervisor::Effects::StateHandler
end

task = MyTask.new
task.add_stage(stage1).add_stage(stage2)

runner = FunctionalTaskSupervisor::Effects::StateTaskRunner.new
result = runner.call(task)

# Access state
result[:history]    # => ['stage1', 'stage2']
result[:metadata]   # => { 'stage1' => {...}, 'stage2' => {...} }
result[:result]     # => Success/Failure
```

### Dependency Injection

Inject dependencies into stages using resolve effects:

```ruby
class LoggingStage < FunctionalTaskSupervisor::Stage
  include FunctionalTaskSupervisor::Effects::ResolveHandler

  private

  def perform_work
    log('Processing data')
    # Access injected dependencies
    data = repo.fetch_data
    Success(data: data)
  end
end

# Provide dependencies
logger = Logger.new($stdout)
repository = MyRepository.new

provider = FunctionalTaskSupervisor::Effects::DependencyProvider.new(
  logger: logger,
  repository: repository
)

result = provider.call(task)
```

### Combined Effects

Use both state tracking and dependency injection:

```ruby
class MyTask < FunctionalTaskSupervisor::Task
  include FunctionalTaskSupervisor::Effects::StateHandler
end

class MyStage < FunctionalTaskSupervisor::Stage
  include FunctionalTaskSupervisor::Effects::ResolveHandler

  private

  def perform_work
    log('Executing stage')
    Success(data: 'done')
  end
end

# Run with combined handler
runner = FunctionalTaskSupervisor::Effects::TaskRunner.new(
  logger: Logger.new($stdout),
  repository: MyRepository.new,
  config: { timeout: 30 }
)

result = runner.call(task)
```

## Conditional Execution

Implement custom stage execution logic:

```ruby
class ConditionalTask < FunctionalTaskSupervisor::Task
  private

  def determine_next_stage(result, current_index)
    # Custom logic to determine next stage
    if result.success?
      current_index + 1
    else
      # Skip to error handling stage
      stages.length - 1
    end
  end
end

task = ConditionalTask.new
task.add_stage(stage1)
    .add_stage(stage2)
    .add_stage(error_handler_stage)

result = task.run_conditional
```

## Error Handling

All exceptions are captured and wrapped in Failure objects:

```ruby
class RiskyStage < FunctionalTaskSupervisor::Stage
  private

  def perform_work
    risky_operation
    Success(data: 'completed')
  rescue StandardError => e
    Failure(
      error: e.message,
      stage: name,
      backtrace: e.backtrace.first(5)
    )
  end
end

stage = RiskyStage.new('risky')
stage.execute

if stage.failure?
  error = stage.error
  puts "Error: #{error[:error]}"
  puts "Stage: #{error[:stage]}"
  puts "Backtrace: #{error[:backtrace]}"
end
```

## Testing

### RSpec

```ruby
require 'spec_helper'

RSpec.describe MyCustomStage do
  let(:stage) { described_class.new('test_stage') }

  it 'executes successfully' do
    stage.execute
    expect(stage.success?).to be true
  end

  it 'returns expected data' do
    stage.execute
    expect(stage.value).to include(data: 'expected')
  end
end
```

### Cucumber

```gherkin
Feature: Task Execution
  Scenario: Execute multi-stage task
    Given I have a task
    And I add a stage named "stage1"
    And I add a stage named "stage2"
    When I run the task
    Then the task should complete successfully
    And all stages should be executed
```

## Advanced Usage

### Transaction Safety

Wrap task execution in database transactions:

```ruby
class TransactionalTask < FunctionalTaskSupervisor::Task
  def run_with_transaction(repository)
    repository.transaction do
      run
    end
  rescue StandardError => e
    # Transaction will be rolled back automatically
    Failure(error: "Transaction failed: #{e.message}")
  end
end
```

### Retry Logic

Implement retry logic for recoverable failures:

```ruby
class RetryableStage < FunctionalTaskSupervisor::Stage
  private

  def recoverable?(failure)
    failure[:error].include?('timeout')
  end

  def retry_with_backoff
    sleep(1)
    perform_work
  end
end
```

## API Reference

### Stage

- `#initialize(name)` - Create a new stage
- `#execute` - Execute the stage
- `#performed?` - Check if stage has been executed
- `#success?` - Check if stage succeeded
- `#failure?` - Check if stage failed
- `#value` - Get the success value
- `#error` - Get the failure error
- `#reset!` - Reset stage to unexecuted state

### Task

- `#initialize` - Create a new task
- `#add_stage(stage)` - Add a stage to the task
- `#run` - Run all stages sequentially
- `#run_conditional` - Run stages with conditional logic
- `#successful_results` - Get all successful results
- `#failed_results` - Get all failed results
- `#all_successful?` - Check if all stages succeeded
- `#any_failed?` - Check if any stage failed
- `#reset!` - Reset all stages

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).

## Credits

Built with:
- [dry-monads](https://dry-rb.org/gems/dry-monads) - Common monads for Ruby
- [dry-effects](https://dry-rb.org/gems/dry-effects) - Algebraic effects in Ruby
