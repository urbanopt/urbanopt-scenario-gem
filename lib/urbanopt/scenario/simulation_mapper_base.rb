# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

module URBANopt
  module Scenario
    class SimulationMapperBase
      # perform initialization functions
      def initialize; end

      # create osw file given a ScenarioBase object, features, and feature_names
      # [parameters:]
      # * +scenario+ - _ScenarioBase_ - An object of ScenarioBase class.
      # * +features+ - _Array_ - Array of Features.
      # * +feature_names+ - _Array_ - Array of scenario specific names for these Features.
      def create_osw(scenario, features, feature_names)
        raise 'create_osw not implemented for SimulationMapperBase, override in your class'
      end
    end
  end
end
