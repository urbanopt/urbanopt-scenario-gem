# *********************************************************************************
# URBANopt™, Copyright (c) 2019-2022, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:

# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.

# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.

# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.

# Redistribution of this software, without modification, must refer to the software
# by the same designation. Redistribution of a modified version of this software
# (i) may not refer to the modified version by the same designation, or by any
# confusingly similar designation, and (ii) must refer to the underlying software
# originally provided by Alliance as “URBANopt”. Except to comply with the foregoing,
# the term “URBANopt”, or any confusingly similar designation may not be used to
# refer to any modified version of this software or any modified version of the
# underlying software originally provided by Alliance without the prior written
# consent of Alliance.

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

# require 'urbanopt/scenario/scenario_post_processor_base'
require 'urbanopt/reporting/default_reports'

require 'csv'
require 'json'
require 'fileutils'

module URBANopt
  module Scenario
    class OpenDSSPostProcessor
      ##
      # OpenDSSPostProcessor post-processes OpenDSS results to selected OpenDSS results and integrate them in scenario and feature reports.
      ##
      # [parameters:]
      # * +scenario_report+ - _ScenarioBase_ - An object of Scenario_report class.
      # * +opendss_results_dir_name+ - _directory name of opendss results
      def initialize(scenario_report, opendss_results_dir_name = 'opendss')
        if !scenario_report.nil?
          @scenario_report = scenario_report
          @opendss_results_dir = File.join(@scenario_report.directory_name, opendss_results_dir_name)
        else
          raise 'scenario_report is not valid'
        end

        # hash of column_name to array of values, does not get serialized to hash
        @mutex = Mutex.new

        # initialize opendss data
        @opendss_data = {}

        # initialize feature_reports data
        @feature_reports_data = {}

        # initialize opendss json results
        @opendss_json_results = {}

        # initialize logger
        @@logger ||= URBANopt::Reporting::DefaultReports.logger
      end

      # load opendss data
      def load_opendss_data
        # load building features data
        @scenario_report.feature_reports.each do |feature_report|
          # read results from opendss
          opendss_csv = CSV.read(File.join(@opendss_results_dir, 'results', 'Features', "#{feature_report.id}.csv"))
          # add results to data
          @opendss_data[feature_report.id] = opendss_csv
        end

        # load Model.json results (if exists)
        opendss_json_filename = File.join(@opendss_results_dir, 'json_files', 'Model.json')
        if File.exists?(opendss_json_filename)
          @opendss_json_results = JSON.parse(File.read(opendss_json_filename))
        end
        
        ## load transformers data

        # transformers results directory path
        tf_results_path = File.join(@opendss_results_dir, 'results', 'Transformers')

        # get transformer ids
        transformer_ids = []
        Dir.entries(tf_results_path.to_s).select do |f|
          if !File.directory? f
            fn = File.basename(f, '.csv')
            transformer_ids << fn
          end
        end

        # add transformer results to @opendss_data
        transformer_ids.each do |id|
          # read results from transformers
          transformer_csv = CSV.read(File.join(tf_results_path, "#{id}.csv"))
          # add results to data
          @opendss_data[id] = transformer_csv
        end
      end

      # load feature report data
      def load_feature_report_data
        @scenario_report.feature_reports.each do |feature_report|
          # read feature results
          feature_csv = CSV.read(File.join(feature_report.timeseries_csv.path))
          # add results to data
          @feature_reports_data[feature_report.id] = feature_csv
        end
      end

      # load feature report data and opendss data
      def load_data
        # load selected opendss data
        load_opendss_data
        # load selected feature reports data
        load_feature_report_data
      end

      # merge data
      def merge_data(feature_report_data, opendss_data)
        output = CSV.generate do |csv|
          opendss_data.each_with_index do |row, i|
            if row.include? 'Datetime'
              row.map { |header| header.prepend('opendss_') }
            end
            csv << (feature_report_data[i] + row[1..])
          end
        end

        return output
      end

      # computer transformer results
      def compute_transformer_results
        # using values from opendss Model.json
        results = {}
        # retrieve all transformers
        trsfmrs = @opendss_json_results['model'].select {|d| d['class'] == 'PowerTransformer' }
        trsfmrs.each do |item|
          t = {'nominal_capacity': nil, 'reactance_resistance_ratio': nil}
          name = item['name']['value']
          
          # nominal capacity in kVA  (Model.json stores it in VA)
          # TODO: assuming that all windings would have the same rated power, so grabbing first one
          begin
            t['nominal_capacity'] = item['windings']['value'][0]['rated_power']['value'] / 1000
          rescue
          end

          # reactance to resistance ratio:
          begin
            # TODO: grabbing the first one for now. Handle when there are multiple reactances and winding resistances
            reactance = item['reactances']['value'][0]['value']
            resistance = item['windings']['value'][0]['resistance']['value']

            t['reactance_resistance_ratio'] = reactance / resistance
          rescue
          end

          results[name] = t
        end

        return results

      end


      # add feature reports for transformers
      def save_transformers_reports

        t_res = compute_transformer_results

        @opendss_data.each_key do |k|
          if k.include? 'Transformer'
            t_key = k.sub('Transformer.', '')
            # create transformer directory
            transformer_dir = File.join(@scenario_report.directory_name, k)
            FileUtils.mkdir_p(File.join(transformer_dir, 'feature_reports'))

            # write data to csv
            # store under voltages and over voltages
            under_voltage_hrs = 0
            over_voltage_hrs = 0
            nominal_capacity = nil
            r_r_ratio = nil
            begin
              nominal_capacity = t_res[t_key]['nominal_capacity']
              r_r_ratio = t_res[t_key]['reactance_resistance_ratio']
            rescue
            end

            transformer_csv = CSV.generate do |csv|
              @opendss_data[k].each_with_index do |row, i|
                csv << row

                if !row[1].include? 'loading'
                  if row[1].to_f > 1.05
                    over_voltage_hrs += 1
                  end

                  if row[1].to_f < 0.95
                    under_voltage_hrs += 1
                  end
                end
              end
            end

            # save transformer CSV report
            File.write(File.join(transformer_dir, 'feature_reports', 'default_feature_report_opendss.csv'), transformer_csv)

            # create transformer report
            transformer_report = URBANopt::Reporting::DefaultReports::FeatureReport.new(id: k, name: k, directory_name: transformer_dir, feature_type: 'Transformer',
                                                                                        timesteps_per_hour: @scenario_report.timesteps_per_hour,
                                                                                        simulation_status: 'complete')

            # assign results to transformer report
            transformer_report.power_distribution.over_voltage_hours = over_voltage_hrs
            transformer_report.power_distribution.under_voltage_hours = under_voltage_hrs
            transformer_report.power_distribution.nominal_capacity = nominal_capacity
            transformer_report.power_distribution.reactance_resistance_ratio = r_r_ratio
            
            ## save transformer JSON file
            # transformer_hash
            transformer_hash = transformer_report.to_hash
            # transformer_hash.delete_if { |k, v| v.nil? }

            json_name_path = File.join(transformer_dir, 'feature_reports', 'default_feature_report_opendss.json')

            # save the json file
            File.open(json_name_path, 'w') do |f|
              f.puts JSON.pretty_generate(transformer_hash)
              # make sure data is written to the disk one way or the other
              begin
                f.fsync
              rescue StandardError
                f.flush
              end
            end

            # add transformers reports to scenario_report
            @scenario_report.feature_reports << transformer_report

          end
        end
      end

      ##
      # Save csv report method
      ##
      # [parameters:]
      # * +feature_report+ - _feature report object_ - An onject of the feature report
      # * +updated_feature_report_csv+ - _CSV_ - An updated feature report csv
      # * +file_name+ - _String_ - Assigned name to save the file with no extension
      def save_csv(feature_report, updated_feature_report_csv, file_name = 'default_feature_report')
        File.write(File.join(feature_report.directory_name, 'feature_reports', "#{file_name}.csv"), updated_feature_report_csv)
      end

      ##
      # create opendss json report results
      ##
      # [parameters:]
      # * +feature_report+ - _feature report object_ - An onject of the feature report
      def add_summary_results(feature_report)
        under_voltage_hrs = 0
        over_voltage_hrs = 0
        kw = nil
        kvar = nil
        nominal_voltage = nil

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

        # also add additional keys for OpenDSS Loads
        loads = @opendss_json_results['model'].select {|d| d['class'] == 'Load'}
        if loads
          bld_load = loads.select {|d| d['name']['value'] == id}
          if bld_load
            if bld_load.kind_of?(Array)
              bld_load = bld_load[0]
            end
            kw = 0
            kvar = 0
            # nominal_voltage (V)
            nominal_voltage = bld_load['nominal_voltage']['value']
            if nominal_voltage < 300
              nominal_voltage = nominal_voltage * Math.sqrt(3)
            end
            nominal_voltage = nominal_voltage
            
            # max_power_kw
            # max_reactive_power_kvar
            pls = bld_load['phase_loads']['value']
            pls.each do |pl|
              kw += pl['p']['value']
              kvar += pl['q']['value']
            end

            kw = kw / 1000
            kvar = kvar / 1000
          else
            @@logger.info("No load matching id #{id} found in OpenDSS Model.json results")
          end
        else
          @@logger.info("No loads information found in OpenDSS Model.json results file")
        end
        # assign results to feature report
        feature_report.power_distribution.over_voltage_hours = over_voltage_hrs
        feature_report.power_distribution.under_voltage_hours = under_voltage_hrs
        feature_report.power_distribution.nominal_voltage = nominal_voltage
        feature_report.power_distribution.max_power_kw = kw
        feature_report.power_distribution.max_reactive_power_kvar = kvar

        return feature_report
      end

      ##
      # save opendss scenario fields
      ##
      def save_opendss_scenario
        
        @scenario_report.scenario_power_distribution = URBANopt::Reporting::DefaultReports::ScenarioPowerDistribution.new

        ## SUBSTATION
        subs = []
        feeders = @opendss_json_results['model'].select {|d| d['class'] == 'Feeder_metadata' }

        feeders.each do |item|
          # nominal_voltage - RMS voltage low side (V)
          substation = {nominal_voltage: item['nominal_voltage']['value']}
          subs.append(substation)  
        end
        @scenario_report.scenario_power_distribution.substations = subs

        ## LINES
        # retrieve all lines
        dist_lines = []
        lines = @opendss_json_results['model'].select {|d| d['class'] == 'Line' }
        lines.each do |item|
          line = {}
          # length (m)
          line['length'] = item['length']['value']

          # max ampacity: iterate through N-1 wires and add up ampacity
          amps = 0
          num_wires = item['wires']['value'].length
          (0..(num_wires - 1)).each do |i|
            amps += item['wires']['value'][i]['ampacity']['value']
          end
          line['ampacity'] = amps

          # commercial line type
          line['commercial_line_type'] = []
          item['wires']['value'].each do |wire|
            line['commercial_line_type'].append(wire['nameclass']['value'])
          end
          dist_lines.append(line)
        end
        @scenario_report.scenario_power_distribution.distribution_lines = dist_lines
        
        # CAPACITORS
        caps = []
        capacitors = @opendss_json_results['model'].select {|d| d['class'] == 'Capacitors' }
        capacitors.each do |item|
          cap = 0
          item['phase_capacitors']['value'].each do |pc|
            if pc['var']['value']
              cap += pc['var']['value']
            end
          end
          caps.append({nominal_capacity: cap})
        end
        @scenario_report.scenario_power_distribution.capacitors = caps
      end

      ##
      # run opendss post_processor
      ##
      def run
        @scenario_report.feature_reports.each do |feature_report|
          # load data
          load_data

          # puts " @opendss data = #{@opendss_data}"

          # get summary results
          add_summary_results(feature_report)

          # merge csv data
          id = feature_report.id
          updated_feature_csv = merge_data(@feature_reports_data[id], @opendss_data[id])

          # save feature reports
          feature_report.save_json_report('default_feature_report_opendss')

          # resave updated csv report
          save_csv(feature_report, updated_feature_csv, 'default_feature_report_opendss')
        end

        # add transformer reports
        save_transformers_reports

        # save additional global opendss fields
        save_opendss_scenario

        # save the updated scenario reports
        # set save_feature_reports to false since only the scenario reports should be saved now
        @scenario_report.save(file_name = 'scenario_report_opendss', save_feature_reports = false)
      end
    end
  end
end
