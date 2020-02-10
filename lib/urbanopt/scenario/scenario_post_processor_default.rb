# *********************************************************************************
# URBANopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC, and other
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
# *********************************************************************************

require 'urbanopt/scenario/scenario_post_processor_base'
require 'urbanopt/scenario/default_reports'
require 'urbanopt/scenario/default_reports/logger'

require 'csv'
require 'json'
require 'fileutils'

require 'sqlite3'


module URBANopt
  module Scenario
    class ScenarioDefaultPostProcessor < ScenarioPostProcessorBase
      ##
      # ScenarioPostProcessorBase post-processes a scenario to create scenario level results
      ##
      # [parameters:]
      # +scenario_base+ - _ScenarioBase_ - An object of ScenarioBase class.
      def initialize(scenario_base)
        super(scenario_base)

        initialization_hash = { directory_name: scenario_base.run_dir, name: scenario_base.name, id: scenario_base.name }
        @scenario_result = URBANopt::Scenario::DefaultReports::ScenarioReport.new(initialization_hash)

        @@logger ||= URBANopt::Scenario::DefaultReports.logger
      end

      ##
      # Run the post processor on this Scenario.This will add all the simulation_dirs.
      ##
      def run
        # this run method adds all the simulation_dirs, you can extend it to do more custom stuff
        @scenario_base.simulation_dirs.each do |simulation_dir|
          add_simulation_dir(simulation_dir)
        end
        return @scenario_result
      end

      ##
      # Add results from a simulation_dir to this result.
      ##
      # [parameters:]
      # +simulation_dir+ - _SimulationDirOSW_ - An object on SimulationDirOSW class.
      def add_simulation_dir(simulation_dir)
        feature_reports = URBANopt::Scenario::DefaultReports::FeatureReport.from_simulation_dir(simulation_dir)

        feature_reports.each do |feature_report|
          if feature_report.to_hash[:simulation_status] == 'Complete'
            @scenario_result.add_feature_report(feature_report)
          else
            @@logger.error("Feature #{feature_report.id} failed to run!")
          end
        end

        return feature_reports
      end

      ##
      # Save scenario result
      ##
      # [parameters:]
      # +file_name+ - _String_ - Assign a name to the saved scenario results file
      def save(file_name = 'default_scenario_report')
        @scenario_result.save

        return @scenario_result
      end

    #   
    #   Save Scenario result in sqlite database file
    # 
    # +db_name+ - _String_ - Assign a name to the saved scenario results database
      def save_db(db_name = "default_scenario_db")
        db = SQLite3::Database.open eplusout.sql
        db.results_as_hash = true
        db.execute "CREATE TABLE IF NOT EXISTS ScenarioData(
            ReportDataIndex INTEGER PRIMARY KEY,
            TimeIndex INTEGER,
            Value REAL
            )"
        feature_list = [] # List of features in the scenario
        value_hash = {}
        query = db.query "SELECT Value FROM ReportData WHERE TimeIndex=?", time_segment
        feature_list.each do |feature|  # Loop through each feature in the scenario
            db = SQLite3::Database.open eplusout.sql
            something = # Need to read each row in the ReportData table individually, so the results can be added to the value_hash
            something.each do |time_segment|  # Loop through each time segment in the table
                value_hash[time_segment] += query  # Add value from table to hash
            end
        end
        db.execute "INSERT INTO ScenarioData ?", value_hash
      end

    end
  end
end
