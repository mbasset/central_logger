Gem::Specification.new do |s|
  s.name = %q{central_logger}
  s.version = File.read("VERSION")

  s.authors = ["Phil Burrows", "Alex Stupka", "Matthew Basset"]
  s.date = %q{2012-03-15}
  s.summary = %q{Central Logger for Rails}
  s.description = %q{Centralized logging for rails apps using MongoDB. The idea and the core code is from http://github.com/peburrows/central_logger}
  s.email = %q{astupka@customink.com}

  s.homepage = %q{http://github.com/customink/central_logger}

  s.required_ruby_version     = ">= 1.9.2"
  s.rubygems_version          = ">= 1.3.7"

  s.add_runtime_dependency('mongoid',   ">= 3.0.14")
  s.add_runtime_dependency('activesupport', ">= 3.2.6")

  s.add_development_dependency('rake',    ">= 0.9.2.2")
  s.add_development_dependency('bundler', ">= 1.1.4")
  s.add_development_dependency('shoulda', ">= 3.1.0")
  s.add_development_dependency('i18n',    ">= 0.6.0")
  s.add_development_dependency('mocha',   ">= 0.12.0")

  s.require_paths = ["lib"]
  s.files = [
    "Gemfile",
    "Gemfile.lock",
    "MIT-LICENSE",
    "README.md",
    "Rakefile",
    "VERSION",
    "central_logger.gemspec",
    "lib/central_logger.rb",
    "lib/central_logger/constants.rb",
    "lib/central_logger/filter.rb",
    "lib/central_logger/initializer.rb",
    "lib/central_logger/initializer_mixin.rb",
    "lib/central_logger/log_message.rb",
    "lib/central_logger/mongo_logger.rb",
    "lib/central_logger/railtie.rb",
    "test/active_record.rb",
    "test/config/samples/central_logger.yml",
    "test/config/samples/database.yml",
    "test/config/samples/database_replica_set.yml",
    "test/config/samples/database_with_auth.yml",
    "test/config/samples/mongoid.yml",
    "test/rails.rb",
    "test/shoulda_macros/log_macros.rb",
    "test/test.sh",
    "test/test_helper.rb",
    "test/unit/central_logger_replica_test.rb",
    "test/unit/central_logger_test.rb"
  ]

  s.extra_rdoc_files = [
    "README.md"
  ]

  s.test_files = [
    "test/active_record.rb",
    "test/rails.rb",
    "test/shoulda_macros/log_macros.rb",
    "test/test_helper.rb",
    "test/unit/central_logger_replica_test.rb",
    "test/unit/central_logger_test.rb"
  ]

end