# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'csv'
require 'date'
require 'json'

module URBANopt
  module Scenario
    class ResultVisualization
      def self.create_visualization(default_report_list, feature = true, feature_names = false)
        @all_results = []
        name = nil

        default_report_list.each do |folder|
          # create visualization for scenarios
          case feature
          when false
            name = folder.split('/')[-2]
            csv_dir = folder

          # create visualization for features
          when true
            index = default_report_list.index(folder)
            name = "#{folder.split('/')[-3]}-#{feature_names[index]}"
            csv_dir = folder
          end

          # get JSON report
          json_report = folder.gsub('.csv', '.json')

          if File.exist?(csv_dir)
            size = CSV.open(csv_dir).readlines.size

            monthly_values = {}
            monthly_totals = {}
            annual_values = {}

            headers_unitless = []
            i = 0
            CSV.foreach(csv_dir).map do |row|
              if i == 0
                # store header values from csv
                headers = row
                headers.each do |header|
                  header_unitless = header.to_s.split('(')[0]
                  headers_unitless << header_unitless
                  monthly_values[header_unitless] = []
                end
              # store values from csv for each row
              elsif i <= size
                headers_unitless.each_index do |j|
                  monthly_values[headers_unitless[j]] << row[j]
                end
              end
              i += 1
            end

            if monthly_values['Datetime'][0].split(/\W+/)[0].to_f > 31
              format = '%Y/%m/%d %H:%M'
              year = monthly_values['Datetime'][0].split(/\W+/)[0]
            else
              format = '%m/%d/%Y %H:%M'
              year = monthly_values['Datetime'][0].split(/\W+/)[2]
            end

            # create dates for each month
            jan_date = DateTime.new(year.to_i, 1, 1, 1, 0)
            feb_date = DateTime.new(year.to_i, 2, 1, 0, 0)
            mar_date = DateTime.new(year.to_i, 3, 1, 0, 0)
            apr_date = DateTime.new(year.to_i, 4, 1, 0, 0)
            may_date = DateTime.new(year.to_i, 5, 1, 0, 0)
            jun_date = DateTime.new(year.to_i, 6, 1, 0, 0)
            jul_date = DateTime.new(year.to_i, 7, 1, 0, 0)
            aug_date = DateTime.new(year.to_i, 8, 1, 0, 0)
            sep_date = DateTime.new(year.to_i, 9, 1, 0, 0)
            oct_date = DateTime.new(year.to_i, 10, 1, 0, 0)
            nov_date = DateTime.new(year.to_i, 11, 1, 0, 0)
            dec_date = DateTime.new(year.to_i, 12, 1, 0, 0)
            jan_next_year = DateTime.new(year.to_i + 1, 1, 1, 0, 0)

            monthly_values['Datetime'].each do |i|
              date_obj = DateTime.strptime(i.to_s, format)
              index = monthly_values['Datetime'].index(i)

              # store index of each date from the csv
              if feb_date == date_obj
                @feb_index = index
              elsif mar_date == date_obj
                @mar_index = index
              elsif apr_date == date_obj
                @apr_index = index
              elsif may_date == date_obj
                @may_index = index
              elsif jun_date == date_obj
                @jun_index = index
              elsif jul_date == date_obj
                @jul_index = index
              elsif aug_date == date_obj
                @aug_index = index
              elsif sep_date == date_obj
                @sep_index = index
              elsif oct_date == date_obj
                @oct_index = index
              elsif nov_date == date_obj
                @nov_index = index
              elsif dec_date == date_obj
                @dec_index = index
              elsif jan_next_year == date_obj
                @jan_next_year_index = index
              end
            end

            headers_unitless.each_index do |j|
              i = 0
              k = 0

              monthly_sum_jan = monthly_sum_feb = monthly_sum_mar = monthly_sum_apr = monthly_sum_may = monthly_sum_jun = monthly_sum_jul = monthly_sum_aug = monthly_sum_sep = monthly_sum_oct = monthly_sum_nov = monthly_sum_dec = annual_sum = 0

              # loop through values for each header
              all_values = monthly_values[headers_unitless[j]]

              unless @jan_next_year_index.nil? || @feb_index.nil? || @mar_index.nil? || @apr_index.nil? || @may_index.nil? || @jun_index.nil? || @jul_index.nil? || @aug_index.nil? || @sep_index.nil? || @oct_index.nil? || @nov_index.nil? || @dec_index.nil?

                # for each header store monthly sums of values
                all_values.each do |v|
                  if i < @feb_index
                    monthly_sum_jan += v.to_f
                    i += 1
                  elsif @feb_index <= i && i < @mar_index
                    monthly_sum_feb += v.to_f
                    i += 1
                  elsif @mar_index <= i && i < @apr_index
                    monthly_sum_mar += v.to_f
                    i += 1
                  elsif @apr_index <= i && i < @may_index
                    monthly_sum_apr += v.to_f
                    i += 1
                  elsif @may_index <= i && i < @jun_index
                    monthly_sum_may += v.to_f
                    i += 1
                  elsif @jun_index <= i && i < @jul_index
                    monthly_sum_jun += v.to_f
                    i += 1
                  elsif @jul_index <= i && i < @aug_index
                    monthly_sum_jul += v.to_f
                    i += 1
                  elsif @aug_index <= i && i < @sep_index
                    monthly_sum_aug += v.to_f
                    i += 1
                  elsif @sep_index <= i && i < @oct_index
                    monthly_sum_sep += v.to_f
                    i += 1
                  elsif @oct_index <= i && i < @nov_index
                    monthly_sum_oct += v.to_f
                    i += 1
                  elsif @nov_index <= i && i < @dec_index
                    monthly_sum_nov += v.to_f
                    i += 1
                  elsif @dec_index <= i && i < @jan_next_year_index
                    monthly_sum_dec += v.to_f
                    i += 1
                  end
                end
              end

              # sum up monthly values for annual aggregate
              annual_sum = monthly_sum_jan + monthly_sum_feb + monthly_sum_mar + monthly_sum_apr + monthly_sum_may + monthly_sum_jun + monthly_sum_jul + monthly_sum_aug + monthly_sum_sep + monthly_sum_oct + monthly_sum_nov + monthly_sum_dec

              # store headers as key and monthly sums as values for each header
              monthly_totals[headers_unitless[j]] = [monthly_sum_jan, monthly_sum_feb, monthly_sum_mar, monthly_sum_apr, monthly_sum_may, monthly_sum_jun, monthly_sum_jul, monthly_sum_aug, monthly_sum_sep, monthly_sum_oct, monthly_sum_nov, monthly_sum_dec]

              annual_values[headers_unitless[j]] = annual_sum
            end

            results = {}
            results['name'] = name
            results['monthly_values'] = {}
            results['annual_values'] = {}
            results['qaqc_flags'] = {}

            if @jan_next_year_index.nil? || @feb_index.nil? || @mar_index.nil? || @apr_index.nil? || @may_index.nil? || @jun_index.nil? || @jul_index.nil? || @aug_index.nil? || @sep_index.nil? || @oct_index.nil? || @nov_index.nil? || @dec_index.nil?
              results['complete_simulation'] = false
              puts "#{name} did not contain an annual simulation…visualizations will not render for it."
            else
              results['complete_simulation'] = true
            end

            monthly_totals&.each do |key, value|
              unless key == 'Datetime'
                results['monthly_values'][key] = value
              end
            end

            annual_values&.each do |key, value|
              unless key == 'Datetime'
                results['annual_values'][key] = value
              end
            end

            # QAQC flags by category (if present)
            if File.exist?(json_report)
              report_data = JSON.parse(File.read(json_report))
              if feature == false
                # adjust nesting for scenario report
                report_data = report_data['scenario_report']
              end

              if report_data.key?('qaqc_flags')
                results['qaqc_flags'] = report_data['qaqc_flags']
              end
            end
          end

          unless results.nil?
            @all_results << results
          end
        end

        # create js file with required data stored in a variable
        if feature == false
          # In case of scenario visualization store result at top of the run folder
          results_path = File.expand_path('../../scenarioData.js', default_report_list[0])
        else
          # In case of feature visualization store result at top of scenario folder folder
          results_path = File.expand_path('../../../scenarioData.js', default_report_list[0])
        end
        File.open(results_path, 'w') do |file|
          file << "var scenarioData = #{JSON.pretty_generate(@all_results)};"
        end
      end
    end
  end
end
