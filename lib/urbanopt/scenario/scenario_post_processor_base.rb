# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

module URBANopt
  module Scenario
    class ScenarioPostProcessorBase
      ##
      # ScenarioPostProcessorBase post-processes a Scenario to create scenario level results.
      ##
      # [parameters:]
      # * +scenario_base+ - _ScenarioBase_ - An object of ScenarioBase class.
      def initialize(scenario_base)
        @scenario_base = scenario_base
      end

      attr_reader :scenario_base

      ##
      # Run the post processor on this Scenario.
      ##
      def run
        raise 'run not implemented for ScenarioPostProcessorBase, override in your class'
      end

      ##
      # Add results from a simulation_dir to this result.
      ##
      # [parameters:]
      # * +simulation_dir+ - _SimulationDirOSW_ - An object on SimulationDirOSW class.
      def add_simulation_dir(simulation_dir)
        raise 'add_simulation_dir not implemented for ScenarioPostProcessorBase, override in your class'
      end

      ##
      # Save scenario result.
      ##
      def save
        raise 'save not implemented for ScenarioPostProcessorBase, override in your class'
      end
    end
  end
end
