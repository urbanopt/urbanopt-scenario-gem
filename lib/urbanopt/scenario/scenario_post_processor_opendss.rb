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

#require 'urbanopt/scenario/scenario_post_processor_base'
require 'urbanopt/scenario/default_reports'
require 'urbanopt/scenario/default_reports/logger'

require 'csv'
require 'json'
require 'fileutils'
require 'pathname'

module URBANopt
  module Scenario
    class OpenDSSPostProcessor
      ##
      # OpenDSSPostProcessor post-processes OpenDSS results to selected OpenDSS results and integrate them in scenario and feature reports.
      ##
      # [parameters:]
      # +scenario_report+ - _ScenarioBase_ - An object of Scenario_report class.
      # +opendss_results_dir_name+ - _directory name of opendss results
      def initialize(scenario_report, opendss_results_dir_name = 'opendss')

        if !scenario_report.nil?
          @scenario_report = scenario_report
          @opendss_results_dir = File.join(@scenario_report.directory_name, opendss_results_dir_name ) 
        else
          raise "scenario_report is not valid"
        end

        # hash of column_name to array of values, does not get serialized to hash
        @mutex = Mutex.new

        # initialize opendss data
        @opendss_data = {}

        # initialize feature_reports data
        @feature_reports_data = {}

        # initialize logger
        @@logger ||= URBANopt::Scenario::DefaultReports.logger
      end


      # load opendss data
      def load_opendss_data()

        @scenario_report.feature_reports.each do |feature_report|
          # read results from opendss
          opendss_csv = CSV.read(File.join(@opendss_results_dir,'results','Features', feature_report.id + '.csv'))
          # add results to data 
          @opendss_data[feature_report.id] = opendss_csv
        end
   
      end


      # load feature report data
      def load_feature_report_data()

        @scenario_report.feature_reports.each do |feature_report|
          # read feature results
          feature_csv = CSV.read(File.join(feature_report.timeseries_csv.path))
          # add results to data
          @feature_reports_data[feature_report.id] = feature_csv
        end

      end

      # load feature report data and opendss data
      def load_data()

        # load selected opendss data
        load_opendss_data()
        # load selected feature reports data
        load_feature_report_data()

      end

      # merge data
      def merge_data(feature_report_data, opendss_data)

        output = CSV.generate do |csv|
          opendss_data.each_with_index do |row, i|
            if row.include? 'Datetime'
              row.map {|header| header.prepend('opendss_')}
            end
            csv << (feature_report_data[i] + row[1..-1])
          end
        end

        return output
        
      end


      ##
      # Save csv report method
      ##
      # [parameters:]
      # +feature_report+ - _feature report object_ - An onject of the feature report
      # +updated_feature_report_csv+ - _CSV_ - An updated feature report csv
      # +file_name+ - _String_ - Assigned name to save the file with no extension
      def save_csv(feature_report, updated_feature_report_csv, file_name = 'default_feature_report')
        File.write(File.join(feature_report.directory_name,'feature_reports',"#{file_name}.csv"), updated_feature_report_csv)
      end


      ##
      # create opendss json report results
      ##
      # [parameters:]
      # +feature_report+ - _feature report object_ - An onject of the feature report
      def add_summary_results(feature_report)

        under_voltage_hrs = 0
        over_voltage_hrs = 0

        id = feature_report.id
        @opendss_data[id].each_with_index do |row, i|
          if !row[1].include? 'voltage'
            
            if row[1].to_f > 1.05
              over_voltage_hrs += 1
            end

            if row[1].to_f < 0.95
              under_voltage_hrs += 1
            end

          end
          
        end

        # assign results to feature report
        feature_report.power_distribution.over_voltage_hours = over_voltage_hrs
        feature_report.power_distribution.under_voltage_hours = under_voltage_hrs

        return feature_report

      end


      ##
      # run opendss post_processor
      ##
      def run
        @scenario_report.feature_reports.each do |feature_report|

          # load data
          load_data()
          
          # get summary results
          add_summary_results(feature_report)

          # merge csv data
          id = feature_report.id
          updated_feature_csv = merge_data(@feature_reports_data[id], @opendss_data[id])

          # save fetaure reports
          feature_report.save_feature_report('default_feature_report_opendss')

          # resave updated csv report
          save_csv(feature_report, updated_feature_csv,'default_feature_report_opendss' )

        end

        # save the updated scenario reports
        @scenario_report.save(file_name = 'scenario_report_opendss')

      end


    end
  end
end