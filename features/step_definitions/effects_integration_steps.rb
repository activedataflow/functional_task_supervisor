# Simple mock logger for testing
class MockLogger
  attr_reader :messages

  def initialize
    @messages = []
  end

  def info(msg)
    @messages << { level: :info, message: msg }
  end

  def warn(msg)
    @messages << { level: :warn, message: msg }
  end

  def error(msg)
    @messages << { level: :error, message: msg }
  end

  def debug(msg)
    @messages << { level: :debug, message: msg }
  end

  def received?(level, message)
    @messages.any? { |m| m[:level] == level && m[:message] == message }
  end
end

Given('I have a task with state tracking') do
  create_task_with_state
  @logger = MockLogger.new
end

Given('I have a task with dependency injection') do
  create_task
  @logger = MockLogger.new
end

Given('I have a task with combined effects') do
  create_task_with_state
  @logger = MockLogger.new
end

Given('I add a stage that uses logger') do
  stage_class = Class.new(FunctionalTaskSupervisor::Stage) do
    include FunctionalTaskSupervisor::Effects::ResolveHandler

    define_method(:initialize) do |task:|
      super(task: task, name: 'logging_stage')
    end

    private

    def perform_work
      log('Executing stage')
      Dry::Monads::Success(data: 'completed')
    end
  end
  add_stage_class_to_task(stage_class)
end

Given('I add stages that use dependencies and state') do
  stage1_class = Class.new(FunctionalTaskSupervisor::Stage) do
    include FunctionalTaskSupervisor::Effects::ResolveHandler

    define_method(:initialize) do |task:|
      super(task: task, name: 'stage1')
    end

    private

    def perform_work
      log('Processing')
      Dry::Monads::Success(data: 'done')
    end
  end

  stage2_class = Class.new(FunctionalTaskSupervisor::Stage) do
    include FunctionalTaskSupervisor::Effects::ResolveHandler

    define_method(:initialize) do |task:|
      super(task: task, name: 'stage2')
    end

    private

    def perform_work
      log('Processing')
      Dry::Monads::Success(data: 'done')
    end
  end

  add_stage_class_to_task(stage1_class)
  add_stage_class_to_task(stage2_class)
end

Given('I add a failing stage with logging') do
  stage_class = Class.new(FunctionalTaskSupervisor::Stage) do
    include FunctionalTaskSupervisor::Effects::ResolveHandler

    define_method(:initialize) do |task:|
      super(task: task, name: 'failing_stage')
    end

    private

    def perform_work
      log('About to fail', level: :error)
      Dry::Monads::Failure(error: 'Intentional failure')
    end
  end
  add_stage_class_to_task(stage_class)
end

When('I run the task with state handler') do
  @runner = FunctionalTaskSupervisor::Effects::StateTaskRunner.new
  @handler_result = @runner.call(@task)
end

When('I run the task with dependency provider') do
  @provider = FunctionalTaskSupervisor::Effects::DependencyProvider.new(logger: @logger)
  @handler_result = @provider.call(@task)
end

When('I run the task with combined handler') do
  @runner = FunctionalTaskSupervisor::Effects::TaskRunner.new(logger: @logger)
  @handler_result = @runner.call(@task)
end

Then('the execution history should contain all stage names') do
  history = @handler_result[:history]
  expected_names = @task.executed_stages.map(&:name)
  expect(history).to eq(expected_names)
end

Then('the metadata should track each stage execution') do
  metadata = @handler_result[:metadata]
  @task.executed_stages.each do |stage|
    expect(metadata).to have_key(stage.name)
    expect(metadata[stage.name]).to include(:index, :success, :timestamp)
  end
end

Then('the stage should have access to the logger') do
  expect(@handler_result).to be_success
end

Then('the logger should record stage execution') do
  expect(@logger.received?(:info, '[logging_stage] Executing stage')).to be true
end

Then('the history should be tracked') do
  expect(@handler_result[:history]).not_to be_empty
end

Then('the dependencies should be available') do
  expect(@logger.messages.any? { |m| m[:level] == :info }).to be true
end

Then('all effects should work together') do
  expect(@handler_result[:history]).not_to be_empty
  expect(@handler_result[:metadata]).not_to be_empty
  expect(@handler_result[:result]).to be_success
end

Then('the failure should be tracked in metadata') do
  metadata = @handler_result[:metadata]
  expect(metadata['failing_stage'][:success]).to be false
end

Then('the failure should be logged') do
  expect(@logger.received?(:error, '[failing_stage] About to fail')).to be true
end
