require_relative 'lib/functional_task_supervisor/version'

Gem::Specification.new do |spec|
  spec.name          = "functional_task_supervisor"
  spec.version       = FunctionalTaskSupervisor::VERSION
  spec.authors       = ["Functional Task Supervisor Team"]
  spec.email         = ["team@example.com"]

  spec.summary       = "Multi-stage task lifecycle with dry-monads and dry-effects"
  spec.description   = "A Ruby gem that implements multi-stage task lifecycle using dry-monads Result types and dry-effects for composable, testable task execution"
  spec.homepage      = "https://github.com/example/functional_task_supervisor"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.3.6"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z 2>/dev/null`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "dry-monads", "~> 1.6"
  spec.add_dependency "dry-effects", "~> 0.4"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "cucumber", "~> 9.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.50"
end
