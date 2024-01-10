# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

# Load in the rake tasks from the base extension gem
require 'openstudio/extension/rake_task'
require 'urbanopt/scenario'
rake_task = OpenStudio::Extension::RakeTask.new
rake_task.set_extension_class(URBANopt::Scenario::Extension, 'urbanopt/urbanopt-scenario-gem')

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task :clear_all do
  Dir.glob(File.join(File.dirname(__FILE__), '/spec/test/example_scenario/*')).each do |f|
    FileUtils.rm_rf(f)
  end
end

task default: :spec
