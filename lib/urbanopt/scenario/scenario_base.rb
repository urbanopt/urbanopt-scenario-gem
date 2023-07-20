# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

module URBANopt
  module Scenario
    # ScenarioBase is a simulation method agnostic description of a Scenario.
    class ScenarioBase
      ##
      # Initialize ScenarioBase attributes: +name+ , +root directory+ , +run directory+ and +feature_file+
      ##
      # [parameters:]
      # * +name+ - _String_ - Human readable scenario name.
      # * +root_dir+ - _String_ - Root directory for the scenario, contains Gemfile describing dependencies.
      # * +run_dir+ - _String_ - Directory for simulation of this scenario, deleting run directory clears the scenario.
      # * +feature_file+ - _FeatureFile_ - An instance of +URBANopt::Core::FeatureFile+ containing features for simulation.
      def initialize(name, root_dir, run_dir, feature_file)
        @name = name
        @root_dir = root_dir
        @run_dir = run_dir
        @feature_file = feature_file
      end

      ##
      # Name of the Scenario.
      attr_reader :name #:nodoc:

      ##
      # Root directory containing Gemfile.
      attr_reader :root_dir #:nodoc:

      ##
      # Directory to run this Scenario.
      attr_reader :run_dir #:nodoc:

      ##
      # An instance of +URBANopt::Core::FeatureFile+ associated with this Scenario.
      attr_reader :feature_file #:nodoc:

      # An array of SimulationDirBase objects.
      def simulation_dirs
        raise 'simulation_dirs not implemented for ScenarioBase, override in your class'
      end

      # Removes all simulation input and output files by removing this Scenario's +run_dir+ .
      def clear
        Dir.glob(File.join(@run_dir, '/*')).each do |f|
          FileUtils.rm_rf(f)
        end
      end
    end
  end
end
