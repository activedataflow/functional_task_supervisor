Feature: Task Execution
  As a developer using functional_task_supervisor
  I want to execute multi-stage tasks
  So that I can manage complex workflows with proper error handling

  Scenario: Execute a simple task with multiple stages
    Given I have a task
    And I add a stage named "fetch_data"
    And I add a stage named "process_data"
    And I add a stage named "save_data"
    When I run the task
    Then the task should complete successfully
    And all stages should be executed
    And the result should include all stage names

  Scenario: Task execution stops on stage failure
    Given I have a task
    And I add a stage named "stage1"
    And I add a failing stage named "failing_stage"
    And I add a stage named "stage3"
    When I run the task
    Then the task should fail
    And only executed stages should be in results

  Scenario: Check stage execution status
    Given I have a task
    And I add a stage named "test_stage"
    When I run the task
    Then the stage "test_stage" should be marked as performed
    And the stage "test_stage" should be successful

  Scenario: Reset task after execution
    Given I have a task
    And I add a stage named "stage1"
    And I add a stage named "stage2"
    When I run the task
    And I reset the task
    Then no stages should be marked as performed
    And the results should be empty

  Scenario: Track successful and failed results
    Given I have a task
    And I add a stage named "success1"
    And I add a failing stage named "failure1"
    When I run the task ignoring errors
    Then I should have both successful and failed results
    And the task should report failures

  Scenario: Custom stage implementation
    Given I have a task
    And I add a custom stage that returns specific data
    When I run the task
    Then the task should complete successfully
    And the stage should return the custom data
