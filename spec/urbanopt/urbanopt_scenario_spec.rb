# *********************************************************************************
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
# *********************************************************************************

require_relative '../spec_helper'
require_relative '../files/example_feature_file'
require 'json'
require 'json-schema'

# rubocop: disable Metrics/BlockLength
RSpec.describe URBANopt::Scenario do
  it 'has a version number' do
    expect(URBANopt::Scenario::VERSION).not_to be nil
  end

  it 'has a logger' do
    expect(URBANopt::Scenario.logger).not_to be nil
    current_level = URBANopt::Scenario.logger.level
    URBANopt::Scenario.logger.level = Logger::DEBUG
    expect(URBANopt::Scenario.logger.level).to eq Logger::DEBUG
    URBANopt::Scenario.logger.level = current_level
  end

  it 'can run a scenario' do
    name = 'Example Scenario'
    
    run_dir = File.join(File.dirname(__FILE__), '../test/example_scenario/')
    feature_file_path = File.join(File.dirname(__FILE__), '../files/example_feature_file.json')
    mapper_files_dir = File.join(File.dirname(__FILE__), '../files/mappers/')
    csv_file = File.join(File.dirname(__FILE__), '../files/example_scenario.csv')
    num_header_rows = 1
    root_dir = File.join(File.dirname(__FILE__), '../../')

    feature_file = ExampleFeatureFile.new(feature_file_path)
    expect(feature_file.features.size).to eq(3)
    expect(feature_file.get_feature_by_id('1')).not_to be_nil
    expect(feature_file.get_feature_by_id('2')).not_to be_nil
    expect(feature_file.get_feature_by_id('3')).not_to be_nil
    expect(feature_file.get_feature_by_id('4')).to be_nil

    # create a new ScenarioCSV, we could create many of these in a project
    scenario = URBANopt::Scenario::ScenarioCSV.new(name, root_dir, run_dir, feature_file, mapper_files_dir, csv_file, num_header_rows)
    expect(scenario.name).to eq(name)
    expect(scenario.root_dir).to eq(root_dir)
    expect(scenario.run_dir).to eq(run_dir)
    expect(scenario.feature_file.path).to eq(feature_file.path)
    expect(scenario.mapper_files_dir).to eq(mapper_files_dir)
    expect(scenario.csv_file).to eq(csv_file)
    expect(scenario.num_header_rows).to eq(1)

    # set clear_results to be false if you want the tests to run faster
    clear_results = true # edited
    scenario.clear if clear_results

    simulation_dirs = scenario.simulation_dirs
    expect(simulation_dirs.size).to eq(3)
    expect(simulation_dirs[0].features.size).to eq(1)
    expect(simulation_dirs[0].feature_names.size).to eq(1)
    expect(simulation_dirs[0].features[0].id).to eq('1')
    expect(simulation_dirs[0].feature_names[0]).to eq('Building 1')
    expect(simulation_dirs[0].mapper_class).to eq('URBANopt::Scenario::TestMapper1')
    expect(simulation_dirs[0].run_dir).to eq(File.join(run_dir, '1/'))

    if clear_results
      expect(File.exist?(simulation_dirs[0].run_dir)).to be false
      expect(File.exist?(simulation_dirs[1].run_dir)).to be false
      expect(File.exist?(simulation_dirs[2].run_dir)).to be false
    end

    # create a ScenarioRunnerOSW to run the ScenarioCSV
    scenario_runner = URBANopt::Scenario::ScenarioRunnerOSW.new

    scenario_runner.create_simulation_files(scenario, clear_results)
    expect(File.exist?(simulation_dirs[0].run_dir)).to be true
    expect(File.exist?(simulation_dirs[1].run_dir)).to be true
    expect(File.exist?(simulation_dirs[2].run_dir)).to be true

    simulation_dirs = scenario_runner.run(scenario)
    if clear_results
      expect(simulation_dirs.size).to eq(3)
      expect(simulation_dirs[0].in_osw_path).to eq(File.join(run_dir, '1/in.osw'))
      expect(simulation_dirs[1].in_osw_path).to eq(File.join(run_dir, '2/in.osw'))
      expect(simulation_dirs[2].in_osw_path).to eq(File.join(run_dir, '3/in.osw'))
    end

    failures = []
    simulation_dirs.each do |simulation_dir|
      run_dir = simulation_dir.run_dir
      simulation_status = simulation_dir.simulation_status
      puts "run_dir = #{run_dir}, simulation_status = #{simulation_status}"
      if simulation_dir.simulation_status != 'Complete'
        failures << run_dir
      end
    end

    expect(failures).to be_empty, "the following directories failed to run [#{failures.join(', ')}]"
    default_post_processor = URBANopt::Scenario::ScenarioDefaultPostProcessor.new(scenario)
    scenario_result = default_post_processor.run
    
    # set a name for the results file 
    scenario_result.save()

    # Add test assertions on scenario_result

    ## Check scenario_report JSON file

    # Read json file
    scenario_json_file = File.open(scenario_result.json_path)
    data = JSON.parse(File.read(scenario_json_file))

    # Program results check
    expect(data['scenario_report']['program']['site_area']).to eq(data['feature_reports'].map { |h| h['program']['site_area'] }.reduce(:+)) if data['scenario_report']['program']['site_area']
    expect(data['scenario_report']['program']['floor_area']).to eq(data['feature_reports'].map { |h| h['program']['floor_area'] }.reduce(:+)) if data['scenario_report']['program']['floor_area']
    expect(data['scenario_report']['program']['conditioned_area']).to eq(data['feature_reports'].map { |h| h['program']['conditioned_area'] }.reduce(:+)) if data['scenario_report']['program']['conditioned_area']
    expect(data['scenario_report']['program']['unconditioned_area']).to eq(data['feature_reports'].map { |h| h['program']['unconditioned_area'] }.reduce(:+)) if data['scenario_report']['program']['unconditioned_area']
    expect(data['scenario_report']['program']['footprint_area']).to eq(data['feature_reports'].map { |h| h['program']['footprint_area'] }.reduce(:+)) if data['scenario_report']['program']['footprint_area']
    expect(data['scenario_report']['program']['maximum_roof_height']).to eq(data['feature_reports'].map { |h| h['program']['maximum_roof_height'] }.max) if data['scenario_report']['program']['maximum_roof_height']
    expect(data['scenario_report']['program']['maximum_number_of_stories']).to eq(data['feature_reports'].map { |h| h['program']['maximum_number_of_stories'] }.max) if data['scenario_report']['program']['maximum_number_of_stories']
    expect(data['scenario_report']['program']['maximum_number_of_stories_above_ground']).to eq(data['feature_reports'].map { |h| h['program']['maximum_number_of_stories_above_ground'] }.max) if data['scenario_report']['program']['maximum_number_of_stories_above_ground']
    expect(data['scenario_report']['program']['parking_area']).to eq(data['feature_reports'].map { |h| h['program']['parking_area'] }.reduce(:+)) if data['scenario_report']['program']['parking_area'] && data['scenario_report']['program']['parking_area']
    expect(data['scenario_report']['program']['number_of_parking_spaces']).to eq(data['feature_reports'].map { |h| h['program']['number_of_parking_spaces'] }.reduce(:+)) if data['scenario_report']['program']['number_of_parking_spaces']
    expect(data['scenario_report']['program']['number_of_parking_spaces_charging']).to eq(data['feature_reports'].map { |h| h['program']['number_of_parking_spaces_charging'] }.reduce(:+)) if data['scenario_report']['program']['number_of_parking_spaces_charging']
    expect(data['scenario_report']['program']['parking_footprint_area']).to eq(data['feature_reports'].map { |h| h['program']['parking_footprint_area'] }.reduce(:+)) if data['scenario_report']['program']['parking_footprint_area']
    expect(data['scenario_report']['program']['maximum_parking_height']).to eq(data['feature_reports'].map { |h| h['program']['maximum_parking_height'] }.max) if data['scenario_report']['program']['maximum_parking_height']
    expect(data['scenario_report']['program']['maximum_number_of_parking_stories']).to eq(data['feature_reports'].map { |h| h['program']['maximum_number_of_parking_stories'] }.max) if data['scenario_report']['program']['maximum_number_of_parking_stories']
    expect(data['scenario_report']['program']['maximum_number_of_parking_stories_above_ground']).to eq(data['feature_reports'].map { |h| h['program']['maximum_number_of_parking_stories_above_ground'] }.max) if data['scenario_report']['program']['maximum_number_of_parking_stories_above_ground']
    expect(data['scenario_report']['program']['number_of_residential_units']).to eq(data['feature_reports'].map { |h| h['program']['number_of_residential_units'] }.reduce(:+)) if data['scenario_report']['program']['number_of_residential_units']

    expect(data['scenario_report']['program']['window_area']['north_window_area']).to eq(data['feature_reports'].map { |h| h['program']['window_area']['north_window_area'] }.reduce(:+)) if data['scenario_report']['program']['window_area']['north_window_area']
    expect(data['scenario_report']['program']['window_area']['south_window_area']).to eq(data['feature_reports'].map { |h| h['program']['window_area']['south_window_area'] }.reduce(:+)) if data['scenario_report']['program']['window_area']['south_window_area']
    expect(data['scenario_report']['program']['window_area']['east_window_area']).to eq(data['feature_reports'].map { |h| h['program']['window_area']['east_window_area'] }.reduce(:+)) if data['scenario_report']['program']['window_area']['east_window_area']
    expect(data['scenario_report']['program']['window_area']['west_window_area']).to eq(data['feature_reports'].map { |h| h['program']['window_area']['west_window_area'] }.reduce(:+)) if data['scenario_report']['program']['window_area']['west_window_area']
    expect(data['scenario_report']['program']['window_area']['total_window_area']).to eq(data['feature_reports'].map { |h| h['program']['window_area']['total_window_area'] }.reduce(:+)) if data['scenario_report']['program']['window_area']['total_window_area']

    expect(data['scenario_report']['program']['wall_area']['north_wall_area']).to eq(data['feature_reports'].map { |h| h['program']['wall_area']['north_wall_area'] }.reduce(:+)) if data['scenario_report']['program']['wall_area']['north_wall_area']
    expect(data['scenario_report']['program']['wall_area']['south_wall_area']).to eq(data['feature_reports'].map { |h| h['program']['wall_area']['south_wall_area'] }.reduce(:+)) if data['scenario_report']['program']['wall_area']['south_wall_area']
    expect(data['scenario_report']['program']['wall_area']['east_wall_area']).to eq(data['feature_reports'].map { |h| h['program']['wall_area']['east_wall_area'] }.reduce(:+)) if data['scenario_report']['program']['wall_area']['east_wall_area']
    expect(data['scenario_report']['program']['wall_area']['west_wall_area']).to eq(data['feature_reports'].map { |h| h['program']['wall_area']['west_wall_area'] }.reduce(:+)) if data['scenario_report']['program']['wall_area']['west_wall_area']
    expect(data['scenario_report']['program']['wall_area']['total_wall_area']).to eq(data['feature_reports'].map { |h| h['program']['wall_area']['total_wall_area'] }.reduce(:+)) if data['scenario_report']['program']['wall_area']['total_wall_area']

    expect(data['scenario_report']['program']['roof_area']['equipment_roof_area']).to eq(data['feature_reports'].map { |h| h['program']['roof_area']['equipment_roof_area'] }.reduce(:+)) if data['scenario_report']['program']['roof_area']['equipment_roof_area']
    expect(data['scenario_report']['program']['roof_area']['photovoltaic_roof_area']).to eq(data['feature_reports'].map { |h| h['program']['roof_area']['photovoltaic_roof_area'] }.reduce(:+)) if data['scenario_report']['program']['roof_area']['photovoltaic_roof_area']
    expect(data['scenario_report']['program']['roof_area']['available_roof_area']).to eq(data['feature_reports'].map { |h| h['program']['roof_area']['available_roof_area'] }.reduce(:+)) if data['scenario_report']['program']['roof_area']['available_roof_area']
    expect(data['scenario_report']['program']['roof_area']['total_roof_area']).to eq(data['feature_reports'].map { |h| h['program']['roof_area']['total_roof_area'] }.reduce(:+)) if data['scenario_report']['program']['roof_area']['total_roof_area']

    # Reporting periods results check
    expect(data['scenario_report']['reporting_periods'][0]['total_site_energy']).to eq(data['feature_reports'].map { |h| h['reporting_periods'][0]['total_site_energy'] }.reduce(:+))


    ##
    # validate all results against schema 
    ##

    # Read scenario schema file
    schema_json = File.open(File.expand_path('../../lib/urbanopt/scenario/default_reports/schema/scenario_schema.json', File.dirname(__FILE__)), 'r')
    schema = JSON.parse(File.read(schema_json))

    # Read scenario json file and validated againt schema
    scenario_json = JSON.parse(File.read(scenario_json_file))

    puts JSON::Validator.fully_validate(schema, scenario_json)
    expect(JSON::Validator.fully_validate(schema, scenario_json).empty?).to be true
    
    # close json file
    scenario_json_file.close

    # Read scenario csv file and validate against schema
    scenario_csv_headers = CSV.open(File.expand_path( scenario_result.csv_path , File.dirname(__FILE__)), &:readline)

    # rubocop: disable Security/Open
    scenario_csv_schema = open(File.expand_path('../../lib/urbanopt/scenario/default_reports/schema/scenario_csv_columns.txt', File.dirname(__FILE__))) # .read()
    # rubocop: enable Security/Open

    scenario_csv_schema_headers = []
    File.readlines(scenario_csv_schema).each do |line|
      l = line.delete("\n")
      a = l.delete("\t")
      scenario_csv_schema_headers << a
    end

    expect(scenario_csv_schema_headers).to eq(scenario_csv_headers)

    # Read feature_reprot json file and validate against schema
    Dir["#{File.dirname(__FILE__)}/../**/*default_feature_reports.json"].each do |json_file|
      feature_json = JSON.parse(File.read(json_file))
      expect(JSON::Validator.fully_validate(schema['definitions']['FeatureReport']['properties'], feature_json).empty?).to be true
    end

    # close schema file
    schema_json.close

  end

end
# rubocop:enable Metrics/BlockLength
