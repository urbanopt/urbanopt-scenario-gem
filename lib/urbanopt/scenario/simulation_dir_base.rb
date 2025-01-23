# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

module URBANopt
  module Scenario
    class SimulationDirBase
      ##
      # SimulationDirBase is the agnostic representation of a directory of simulation input files.
      ##
      # [parameters:]
      # * +scenario+ - _ScenarioBase_ - Scenario containing this SimulationDirBase.
      # * +features+ - _Array_ - Array of Features that this SimulationDirBase represents.
      # * +feature_names+ - _Array_ - Array of scenario specific names for these Features.
      def initialize(scenario, features, feature_names)
        @scenario = scenario
        @features = features
        @feature_names = feature_names
      end

      attr_reader :scenario, :features, :feature_names #:nodoc: #:nodoc: #:nodoc:

      ##
      # Return the directory that this simulation will run in
      ##
      def run_dir
        raise 'run_dir is not implemented for SimulationFileBase, override in your class'
      end

      ##
      # Return true if the simulation is out of date (input files newer than results), false otherwise.
      # Non-existent simulation input files are out of date.
      ##
      def out_of_date?
        raise 'out_of_date? is not implemented for SimulationFileBase, override in your class'
      end

      ##
      #  Returns simulation status one of {'Not Started', 'Started', 'Complete', 'Failed'}
      ##
      def simulation_status
        raise 'simulation_status is not implemented for SimulationFileBase, override in your class'
      end

      ##
      # Clear the directory that this simulation runs in
      ##
      def clear
        raise 'clear is not implemented for SimulationFileBase, override in your class'
      end

      ##
      # Create run directory and generate simulation inputs, all previous contents of directory are removed
      ##
      def create_input_files
        raise 'create_input_files is not implemented for SimulationFileBase, override in your class'
      end
    end
  end
end
