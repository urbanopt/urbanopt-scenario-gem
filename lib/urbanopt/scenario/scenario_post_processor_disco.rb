# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'urbanopt/reporting/default_reports'

require 'csv'
require 'json'
require 'fileutils'

module URBANopt
  module Scenario
    class DISCOPostProcessor
      ##
      # DISCOPostProcessor post-processes DISCO results to selected DISCO results and
      # integrate them in scenario and feature reports.
      ##
      # [parameters:]
      # * +scenaro_report+ - _ScenarioBase_ - An object of Scenario_report class.
      # * +disco_results_dir_name+ - _directory name of disco results
      def initialize(scenario_report, disco_results_dir_name = 'disco')
        if !scenario_report.nil?
          @scenario_report = scenario_report
          @disco_results_dir = File.join(@scenario_report.directory_name, disco_results_dir_name)
        else
          raise 'scenario_report is not valid'
        end

        # initialize disco data
        @disco_data = {}

        # initialize disco json results
        @disco_json_results = {}

        # initialize logger
        @@logger ||= URBANopt::Reporting::DefaultReports.logger
      end

      # load disco data (if exists)
      def load_disco_data
        # load disco upgrade summary
        disco_json_filename = File.join(@disco_results_dir, 'upgrade_summary.json')
        if File.exist?(disco_json_filename)
          @disco_json_results = JSON.parse(File.read(disco_json_filename))
        end
      end

      # load disco data
      def load_data
        # load selected disco data
        load_disco_data
      end

      ##
      # save disco scenario fields
      ##
      def save_disco_scenario
        @scenario_report.scenario_power_distribution_cost = URBANopt::Reporting::DefaultReports::ScenarioPowerDistributionCost.new

        # RESULTS

        res = []
        # read result from JSON report
        res = @disco_json_results['results']
        @scenario_report.scenario_power_distribution_cost.results = res

        # OUTPUTS

        out = {}
        # read result from JSON report
        out[:log_file] = @disco_json_results['outputs']['log_file']
        out[:jobs] = []
        @disco_json_results['outputs']['jobs'].each do |job|
          out[:jobs] << job
        end
        @scenario_report.scenario_power_distribution_cost.outputs = out

        # VIOLATION SUMMARY

        vio = []
        # read result from JSON report
        vio = @disco_json_results['violation_summary']
        @scenario_report.scenario_power_distribution_cost.violation_summary = vio

        # COSTS PER EQUIPMENT
        cos = []
        # read result from JSON report
        cos = @disco_json_results['costs_per_equipment']
        @scenario_report.scenario_power_distribution_cost.costs_per_equipment = cos

        # EQUIPMENT
        equ = []
        # read result from JSON report
        equ = @disco_json_results['equipment']
        @scenario_report.scenario_power_distribution_cost.equipment = equ
      end

      ##
      # run disco post_processor
      ##
      def run
        # load data
        load_data
        # save additional global disco fields
        save_disco_scenario

        # save the updated scenario reports
        # set save_feature_reports to false since only the scenario reports should be saved
        # now, set save csv reports to false
        @scenario_report.save(file_name = 'scenario_report_disco', save_feature_reports = false, save_csv_reports = false)
      end
    end
  end
end
