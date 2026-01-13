Feature: Effects Integration
  As a developer using functional_task_supervisor
  I want to use dry-effects for state management and dependency injection
  So that I can build composable and testable task workflows

  Scenario: Track stage execution history with state effects
    Given I have a task with state tracking
    And I add a stage named "stage1"
    And I add a stage named "stage2"
    And I add a stage named "stage3"
    When I run the task with state handler
    Then the execution history should contain all stage names
    And the metadata should track each stage execution

  Scenario: Inject dependencies into stages
    Given I have a task with dependency injection
    And I add a stage that uses logger
    When I run the task with dependency provider
    Then the stage should have access to the logger
    And the logger should record stage execution

  Scenario: Combine state tracking and dependency injection
    Given I have a task with combined effects
    And I add stages that use dependencies and state
    When I run the task with combined handler
    Then the history should be tracked
    And the dependencies should be available
    And all effects should work together

  Scenario: Handle failures with effects
    Given I have a task with state tracking
    And I add a failing stage with logging
    When I run the task with combined handler
    Then the failure should be tracked in metadata
    And the failure should be logged
