# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-09

### Added
- Initial release of functional_task_supervisor
- Core Stage class with Result monad integration
- Core Task class with Do notation support
- Multi-stage lifecycle management (nil/Success/Failure states)
- dry-effects integration for state tracking
- dry-effects integration for dependency injection
- StateHandler module for tracking stage execution history
- ResolveHandler module for dependency injection
- Combined TaskRunner for both state and dependencies
- Conditional stage execution support
- Comprehensive RSpec test suite
- Cucumber feature tests for integration testing
- Full documentation and examples
- MIT License

### Features
- Type-safe error handling with dry-monads
- Composable effects with dry-effects
- Clean syntax with Do notation
- Transaction safety support
- Precondition validation
- Custom stage implementation
- Error recovery and retry logic
- Stage reset functionality
- Task reset functionality

[0.1.0]: https://github.com/example/functional_task_supervisor/releases/tag/v0.1.0
