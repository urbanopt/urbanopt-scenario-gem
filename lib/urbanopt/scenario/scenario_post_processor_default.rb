# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'urbanopt/scenario/scenario_post_processor_base'
require 'urbanopt/reporting/default_reports'

require 'csv'
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
          Year VARCHAR(255),
          Month VARCHAR(255),
          Day VARCHAR(255),
          Hour VARCHAR(255),
          Minute VARCHAR(255),
          Dst INTEGER,
          FuelType VARCHAR(255),
          Value INTEGER,
          FuelUnits VARCHAR(255)
          )"

        values_arr = []
        feature_list = Pathname.new(@initialization_hash[:directory_name]).children.select(&:directory?) # Folders in the run/scenario directory

        # get scenario CSV
        scenario_csv = File.join(@initialization_hash[:root_dir], "#{@initialization_hash[:name]}.csv")
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
        feature_list.each do |feature| # Loop through each feature in the scenario
          uo_output_sql_file = File.join(@initialization_hash[:directory_name], File.basename(feature), 'eplusout.sql')
          feature_db = SQLite3::Database.open uo_output_sql_file
          # Doing "db.results_as_hash = true" is prettier, but in this case significantly slower.

          elec_query = feature_db.query "SELECT ReportData.TimeIndex, Time.Year, Time.Month, Time.Day, Time.Hour,
            Time.Minute, Time.Dst, ReportData.Value
          FROM ReportData
          INNER JOIN Time ON Time.TimeIndex=ReportData.TimeIndex
          INNER JOIN ReportDataDictionary AS rddi ON rddi.ReportDataDictionaryIndex=ReportData.ReportDataDictionaryIndex
          WHERE rddi.IndexGroup == 'Facility:Electricity'
          AND rddi.ReportingFrequency == 'Zone Timestep'
          AND Time.Year > 1900
          ORDER BY ReportData.TimeIndex"

          elec_query.each do |row| # Add up all the values for electricity usage across all Features at this timestep
            # row[0] == TimeIndex, row[1] == Value

            arr_match = values_arr.find { |v| v[:time_index] == row[0] }
            if arr_match.nil?
              # add new row to value_arr
              values_arr << { time_index: row[0], year: row[1], month: row[2], day: row[3], hour: row[4], minute: row[5], dst: row[6], elec_val: Float(row[7]), gas_val: 0 }
            else
              # running sum
              arr_match[:elec_val] += Float(row[7])
            end
          end
          elec_query.close

          gas_query = feature_db.query "SELECT ReportData.TimeIndex, Time.Year, Time.Month, Time.Day, Time.Hour,
            Time.Minute, Time.Dst, ReportData.Value
          FROM ReportData
          INNER JOIN Time ON Time.TimeIndex=ReportData.TimeIndex
          INNER JOIN ReportDataDictionary AS rddi ON rddi.ReportDataDictionaryIndex=ReportData.ReportDataDictionaryIndex
          WHERE rddi.IndexGroup == 'Facility:Gas'
          AND rddi.ReportingFrequency == 'Zone Timestep'
          AND Time.Year > 1900
          ORDER BY ReportData.TimeIndex"

          gas_query.each do |row|
            # row[0] == TimeIndex, row[1] == Value
            arr_match = values_arr.find { |v| v[:time_index] == row[0] }
            if arr_match.nil?
              # add new row to value_arr
              values_arr << { time_index: row[0], year: row[1], month: row[2], day: row[3], hour: row[4], minute: row[5], dst: row[6], gas_val: Float(row[7]), elec_val: 0 }
            else
              # running sum
              arr_match[:gas_val] += Float(row[7])
            end
          end
          gas_query.close
          feature_db.close
        end

        elec_sql = []
        gas_sql = []
        values_arr.each do |i|
          elec_sql << "(#{i[:time_index]}, #{i[:year]}, #{i[:month]}, #{i[:day]}, #{i[:hour]}, #{i[:minute]}, #{i[:dst]}, 'Electricity', #{i[:elec_val]}, 'J')"
          gas_sql << "(#{i[:time_index]}, #{i[:year]}, #{i[:month]}, #{i[:day]}, #{i[:hour]}, #{i[:minute]}, #{i[:dst]}, 'Gas', #{i[:gas_val]}, 'J')"
        end

        # Put summed Values into the database
        scenario_db.execute("INSERT INTO ReportData VALUES #{elec_sql.join(', ')}")
        scenario_db.execute("INSERT INTO ReportData VALUES #{gas_sql.join(', ')}")
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
