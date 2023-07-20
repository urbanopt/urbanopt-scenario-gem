# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

module URBANopt
  module Scenario
    class ScenarioRunnerBase
      ##
      # ScenarioRunnerBase is the agnostic interface for a class which can create and run SimulationFiles.
      ##
      def initialize; end

      ##
      # Create all SimulationDirs for Scenario.
      ##
      # [parameters:]
      # * +scenario+ - _ScenarioBase_ - Scenario to create simulation input files for scenario.
      # * +force_clear+ - _Bool_ - Clear Scenario before creating simulation input files
      ##
      # [return:] _Array_ Returns an array of all SimulationDirs, even those created previously, for Scenario.
      def create_simulation_files(scenario, force_clear = false)
        raise 'create_input_files is not implemented for ScenarioRunnerBase, override in your class'
      end

      ##
      # Create and run all SimulationFiles for Scenario.
      ##
      # [parameters:]
      # * +scenario+ - _ScenarioBase_ - Scenario to create and run simulation input files for.
      # * +force_clear+ - _Bool_ - Clear Scenario before creating Simulation input files.
      ##
      # [return:] _Array_ Returns an array of all SimulationDirs, even those created previously, for Scenario.
      def run(scenario, force_clear = false, options = {})
        raise 'run is not implemented for ScenarioRunnerBase, override in your class'
      end
    end
  end
end
