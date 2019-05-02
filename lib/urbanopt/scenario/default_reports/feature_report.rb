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

require "urbanopt/scenario/default_reports/construction_costs"
require "urbanopt/scenario/default_reports/program"
require "urbanopt/scenario/default_reports/reporting_periods"
require "urbanopt/scenario/default_reports/timeseries_csv"

require 'json'

module URBANopt
  module Scenario
    module DefaultReports
    
      ## 
      # FeatureReport generate two types of reports in a simulation_dir.  
      # The 'default_feature_reports' measure writes a 'default_feature_reports.json' file containing 
      # information on all features in the simulation.  It also writes a 'default_feature_reports.csv'
      # containing timeseries data for all features in the simulation.
      # The DefaultPostProcessor reads in these FeatureReports and aggregates them to create a ScenarioReport.
      ##
      class FeatureReport 
        attr_accessor :id, :name, :directory_name, :feature_type, :timesteps_per_hour, :simulation_status, :timeseries_csv, :program, :construction_costs, :reporting_periods
        
        ##
        # Each FeatureReport object corresponds to a single Feature.
        ##
        #  @param [Hash] hash A hash which may contain a deserialized feature_report
        def initialize(hash = {})
          hash.delete_if {|k, v| v.nil?}
          hash = defaults.merge(hash)
          
          @id = hash[:id]
          @name = hash[:name]
          @directory_name = hash[:directory_name]
          @feature_type = hash[:feature_type]
          @simulation_status = hash[:simulation_status]
          @timeseries_csv = TimeseriesCSV.new(hash[:timeseries_csv])
          @program = Program.new(hash[:program])
          @construction_costs = ConstructionCosts.new(hash[:construction_costs])
          @reporting_periods = ReportingPeriods.new (hash[:reporting_periods])
        end
        
        def defaults
          hash = {}
          hash[:timeseries_csv] = {}
          hash[:program] = {}
          hash[:construction_costs] = {}
          hash[:reporting_periods] = {}
          return hash
        end
        
        ##
        # Return an Array of FeatureReports for the simulation_dir as multiple Features can be simulated together in a single simulation directory.
        ##
        #  @param [SimulationDirOSW] simulation_dir A simulation directory from an OSW simulation, must include 'default_feature_reports' measure
        def self.from_simulation_dir(simulation_dir)
          
          result = []
          
          # simulation dir can include only one feature
          features = simulation_dir.features
          if features.size != 1
            raise "FeatureReport cannot support multiple features per OSW"
          end

          # read in the reports written by measure
          default_feature_reports_json = nil
          default_feature_reports_csv = nil
          
          simulation_status = simulation_dir.simulation_status
          if simulation_status == 'Complete' || simulation_status == 'Failed' 
            
            # read in the scenario reports JSON and CSV
            Dir.glob(File.join(simulation_dir.run_dir, '*_default_feature_reports/')).each do |dir|
              scenario_reports_json_path = File.join(dir, 'default_feature_reports.json')
              if File.exists?(scenario_reports_json_path)
                File.open(scenario_reports_json_path, 'r') do |file|
                  default_feature_reports_json = JSON.parse(file.read, symbolize_names: true)
                end
              end
              scenario_reports_csv_path = File.join(dir, 'default_feature_reports.csv')
              if File.exists?(scenario_reports_csv_path)
                default_feature_reports_csv = scenario_reports_csv_path
              end              
            end
            
          end
          
          # if we loaded the json
          if default_feature_reports_json && default_feature_reports_json[:feature_reports]
            default_feature_reports_json[:feature_reports].each do |feature_report|
              result << FeatureReport.new(feature_report)
            end
          else
            # we did not find a report
            features.each do |feature|
              hash = {}
              hash[:id] = feature.id
              hash[:name] = feature.name
              hash[:directory_name] = simulation_dir.run_dir
              hash[:simulation_status] = simulation_status
              result << FeatureReport.new(hash)
            end
          end
          
          return result
        end
        
        ##
        # Convert to a Hash equivalent for JSON serialization
        ##
        def to_hash
          result = {}
          result[:id] = @id if @id
          result[:name] = @name if @name
          result[:directory_name] = @directory_name if @directory_name
          result[:feature_type] = @feature_type if @feature_type
          result[:timesteps_per_hour] = @timesteps_per_hour if @timesteps_per_hour
          result[:simulation_status] = @simulation_status if @simulation_status
          result[:timeseries_csv] = @timeseries_csv.to_hash
          result[:program] = @program.to_hash
          result[:construction_costs] = @construction_costs.to_hash
          result[:reporting_periods] = @reporting_periods.to_hash
          return result
        end
       
      end
    end
  end
end