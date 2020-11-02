# *********************************************************************************
# URBANopt (tm), Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC, and other
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
require 'urbanopt/reporting/default_reports'

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
      # * +scenario_base+ - _ScenarioBase_ - An object of ScenarioBase class.
      def initialize(scenario_base)
        super(scenario_base)

        @initialization_hash = { directory_name: scenario_base.run_dir, name: scenario_base.name, id: scenario_base.name, root_dir: scenario_base.root_dir }
        @scenario_result = URBANopt::Reporting::DefaultReports::ScenarioReport.new(@initialization_hash)
        @default_save_name = 'default_scenario_report'

        @@logger ||= URBANopt::Reporting::DefaultReports.logger
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
      # * +simulation_dir+ - _SimulationDirOSW_ - An object on SimulationDirOSW class.
      def add_simulation_dir(simulation_dir)
        feature_reports = URBANopt::Reporting::DefaultReports::FeatureReport.from_simulation_dir(simulation_dir)

        feature_reports.each do |feature_report|
          if feature_report.to_hash[:simulation_status] == 'Complete'
            @scenario_result.add_feature_report(feature_report)
          else
            @@logger.error("Feature #{feature_report.id} failed to run!")
          end
        end

        return feature_reports
      end

      # Create database file with scenario-level results
      #   Sum values for each timestep across all features. Save to new table in a new database
      ##
      # [parameters:]
      # * +file_name+ - _String_ - Assign a name to the saved scenario results file
      def create_scenario_db_file(file_name = @default_save_name)
        new_db_file = File.join(@initialization_hash[:directory_name], "#{file_name}.db")
        scenario_db = SQLite3::Database.open new_db_file
        scenario_db.execute "CREATE TABLE IF NOT EXISTS ReportData(
          TimeIndex INTEGER,
          Year INTEGER,
          Month INTEGER,
          Day INTEGER,
          Hour INTEGER,
          Minute INTEGER,
          Dst INTEGER,
          DC_inlet_temp DECIMAL (5,2),
          DC_it_units VARCHAR(10),
          DC_outlet_temp DECIMAL (5,2),
          DC_ot_units VARCHAR(10),
          DC_mass_flow_rate DECIMAL (6,3),
          DC_mfr_units VARCHAR(10),
          DH_inlet_temp DECIMAL (5,2),
          DH_it_units VARCHAR(10),
          DH_outlet_temp DECIMAL (5,2),
          DH_ot_units VARCHAR(10),
          DH_mass_flow_rate DECIMAL (6,3),
          DH_mfr_units VARCHAR (10),
          Gas_usage FLOAT,
          Gas_usage_units VARCHAR (10),
          Electricity_usage FLOAT,
          Electricity_usage_units VARCHAR(10)
          )"

        values_arr = []
        feature_list = Pathname.new(@initialization_hash[:directory_name]).children.select(&:directory?) # Folders in the run/scenario directory

        # get scenario CSV
        scenario_csv = File.join(@initialization_hash[:root_dir], @initialization_hash[:name] + '.csv')
        if File.exist?(scenario_csv)
          # csv found
          feature_ids = CSV.read(scenario_csv, headers: true)
          feature_list = []
          # loop through building feature ids from scenario csv
          feature_ids['Feature Id'].each do |feature|
            if Dir.exist?(File.join(@initialization_hash[:directory_name], feature))
              feature_list << File.join(@initialization_hash[:directory_name], feature)
            else
              puts "warning: did not find a directory for datapoint #{feature}...skipping"
            end
          end
        else
          raise "Couldn't find scenario CSV: #{scenario_csv}"
        end
        feature_1_name = File.basename(feature_list[0]) # Get name of first feature, so we can read eplusout.sql from there
        uo_output_sql_file = File.join(@initialization_hash[:directory_name], feature_1_name, 'eplusout.sql')
        feature_list.each do |feature| # Loop through each feature in the scenario
          feature_db = SQLite3::Database.open uo_output_sql_file
          # Doing "db.results_as_hash = true" is prettier, but in this case significantly slower.

          # This query pivots the data so each value requested in the rddi becomes its own column for a single time index
          query = feature_db.query "Select  tindex, year, month, day, hour, minute, dst,
              max(case when col_name = 'District Cooling Inlet Temperature' then IFNULL(col_value,0) end) dc_it,
              max(case when col_name = 'District Cooling Inlet Temperature' then col_unit end) dc_it_units,
              max(case when col_name = 'District Cooling Outlet Temperature' then IFNULL(col_value,0) end) dc_ot,
              max(case when col_name = 'District Cooling Outlet Temperature' then col_unit end) dc_ot_units,
              max(case when col_name = 'District Cooling Mass Flow Rate' then IFNULL(col_value,0) end) dc_mfr,
              max(case when col_name = 'District Cooling Mass Flow Rate' then col_unit end) dc_mfr_units,
              max(case when col_name = 'District Heating Inlet Temperature' then IFNULL(col_value,0) end) dh_it,
              max(case when col_name = 'District Heating Inlet Temperature' then col_unit end) dh_it_units,
              max(case when col_name = 'District Heating Outlet Temperature' then IFNULL(col_value,0) end) dh_ot,
              max(case when col_name = 'District Heating Outlet Temperature' then col_unit end) dh_ot_units,
              max(case when col_name = 'District Heating Mass Flow Rate' then IFNULL(col_value,0) end) dh_mfr,
              max(case when col_name = 'District Heating Mass Flow Rate' then col_unit end) dh_mfr_units,
              max(case when col_name = 'Gas:Facility' then IFNULL(col_value,0) end) gas_val,
              max(case when col_name = 'Gas:Facility' then col_unit end) gas_units,
              max(case when col_name = 'Electricity:Facility' then IFNULL(col_value,0) end) elec_val,
              max(case when col_name = 'Electricity:Facility' then col_unit end) elec_units
            from (
              SELECT ReportData.TimeIndex as tindex,
                Time.Year as year, Time.Month as month, Time.Day as day, Time.Hour as hour, Time.Minute as minute, Time.Dst as dst,
                rddi.Name as col_name,
                ReportData.Value as col_value,
                rddi.Units as col_unit
              FROM ReportData
              INNER JOIN Time ON Time.TimeIndex=tindex
              INNER JOIN ReportDataDictionary AS rddi ON rddi.ReportDataDictionaryIndex=ReportData.ReportDataDictionaryIndex
              WHERE year > 1900
              AND rddi.ReportingFrequency = 'Zone Timestep'
                AND (rddi.Name = 'Gas:Facility'
                OR rddi.Name = 'Electricity:Facility'
                OR rddi.Name = 'District Heating Mass Flow Rate'
                OR rddi.Name = 'District Heating Inlet Temperature'
                OR rddi.Name = 'District Heating Outlet Temperature'
                OR rddi.Name = 'District Cooling Mass Flow Rate'
                OR rddi.Name = 'District Cooling Inlet Temperature'
                OR rddi.Name = 'District Cooling Outlet Temperature' )
              ORDER BY tindex
            )
          group by tindex;"

          query.each do |row| # Add up all the values for electricity usage across all Features at this timestep

            arr_match = values_arr.find { |v| v[:time_index] == row[0] }
            if arr_match.nil?
              # add new row to value_arr
            values_arr << { time_index: row[0], year: row[1], month: row[2], day: row[3], hour: row[4], minute: row[5],
              dst: row[6], dc_it: row[7], dc_it_units: row[8], dc_ot: row[9], dc_ot_units: row[10],
              dc_mfr: row[11], dc_mfr_units: row[12], dh_it: row[13], dh_it_units: row[14], dh_ot: row[15],
              dh_ot_units: row[16], dh_mfr: row[17], dh_mfr_units: row[18], gas_val: row[19], gas_units: row[20],
              elec_val: row[21], elec_units: row[22] }
            else
              # running sum
              arr_match[:dc_it] += row[7]
              arr_match[:dc_ot] += row[9]
              arr_match[:dc_mfr] += row[11]
              arr_match[:dh_it] += row[13]
              arr_match[:dh_ot] += row[15]
              arr_match[:dh_mfr] += row[17]
              arr_match[:gas_val] += row[19]
              arr_match[:elec_val] += row[21]
            end
          end # End query
          query.close
          feature_db.close
        end # End feature_list loop

        sql_array = []
        values_arr.each do |i|
          sql_array << "(#{i[:time_index]}, #{i[:year]}, #{i[:month]}, #{i[:day]}, #{i[:hour]}, #{i[:minute]}, #{i[:dst]},
          #{i[:dc_it]}, #{i[:dc_it_units]}, #{i[:dc_ot]}, #{i[:dc_ot_units]}, #{i[:dc_mfr]}, #{i[:dc_mfr_units]}, #{i[:dh_it]},
          #{i[:dh_it_units]}, #{i[:dh_ot]}, #{i[:dh_ot_units]}, #{i[:dh_mfr]}, #{i[:dh_mfr_units]}, #{i[:gas_val]}, #{i[:gas_units]},
          #{i[:elec_val]}, #{i[:elec_units]})"
        end

        # Put summed Values into the database
        puts ""
        puts "sql_array[0]"
        puts sql_array[1]
        puts ""
        scenario_db.execute("INSERT INTO ReportData VALUES #{sql_array.join(', ')}")
        scenario_db.close
      end

      ##
      # Save scenario result
      ##
      # [parameters:]
      # * +file_name+ - _String_ - Assign a name to the saved scenario results file
      def save(file_name = @default_save_name)
        @scenario_result.save

        return @scenario_result
      end
    end
  end
end
