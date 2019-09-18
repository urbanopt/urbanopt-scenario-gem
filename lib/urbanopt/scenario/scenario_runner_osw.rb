#*********************************************************************************
# URBANopt, Copyright (c) 2019, Alliance for Sustainable Energy, LLC, and other 
# contributors. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, 
# are permitted provided that the following conditions are met:
# 
# Redistributions of source code must retain the above copyright notice, this list 
# of conditions and the following disclaimer.
# 
# Redistributions in binary form must reproduce the above copyright notice, this 
# list of conditions and the following disclaimer in the documentation and/or other 
# materials provided with the distribution.
# 
# Neither the name of the copyright holder nor the names of its contributors may be 
# used to endorse or promote products derived from this software without specific 
# prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
# OF THE POSSIBILITY OF SUCH DAMAGE.
#*********************************************************************************

require "urbanopt/scenario/scenario_runner_base"

require 'fileutils'

module URBANopt
  module Scenario
    class ScenarioRunnerOSW < ScenarioRunnerBase
      
      ## 
      # ScenarioRunnerOSW is a class to create and run SimulationFileOSWs
      ##
      def initialize()
      end

      ##
      # Create all OSWs for Scenario
      ##
      # scenario::
      #   [ScenarioBase] Scenario to create simulation input files for
      # force_clear::
      #   [Bool] Clear Scenario before creating simulation input files
      # @return::
      #   [Array] Returns array of all SimulationDirs, even those created previously, for Scenario
      def create_simulation_files(scenario, force_clear = false)
        
        if force_clear
          scenario.clear
        end
        
        FileUtils.mkdir_p(scenario.run_dir) if !File.exists?(scenario.run_dir)
        
        simulation_dirs = scenario.simulation_dirs
        
        simulation_dirs.each do |simulation_dir|
          if simulation_dir.out_of_date?
            puts "simulation_dir #{simulation_dir.run_dir} is out of date, regenerating input files"
            simulation_dir.create_input_files
          end
        end

        return simulation_dirs
      end
      
      ##
      # Create and run all SimulationFileOSW for Scenario
      ##
      # scenario::
      #   [ScenarioBase] Scenario to create and run SimulationFiles for
      # force_clear::
      #   [Bool] Clear Scenario before creating SimulationFiles
      # @return::
      #   [Array] Returns array of all SimulationFiles, even those created previously, for Scenario
      def run(scenario, force_clear = false)
        runner = OpenStudio::Extension::Runner.new(scenario.root_dir)

        simulation_dirs = create_simulation_files(scenario, force_clear)
        
        osws = []
        simulation_dirs.each do |simulation_dir|
          if !simulation_dir.is_a?(SimulationDirOSW)
            raise "ScenarioRunnerOSW does not know how to run #{simulation_dir.class}"
          end
          if simulation_dir.out_of_date?
            osws << simulation_dir.in_osw_path
          end
        end
        
        failures = runner.run_osws(osws)
        
        return simulation_dirs
      end
      
    end
  end
end