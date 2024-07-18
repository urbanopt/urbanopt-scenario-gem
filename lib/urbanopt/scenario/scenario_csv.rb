# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'urbanopt/scenario/scenario_base'
require 'urbanopt/scenario/simulation_dir_osw'

require 'csv'
require 'fileutils'

module URBANopt
  module Scenario
    class ScenarioCSV < ScenarioBase
      ##
      # ScenarioCSV is a ScenarioBase which assigns a Simulation Mapper to each Feature in a FeatureFile using a simple CSV format.
      # The CSV file has three columns 1) feature_id, 2) feature_name, and 3) mapper_class_name.  There is one row for each Feature.
      ##
      # [parameters:]
      # * +name+ - _String_ - Human readable scenario name.
      # * +root_dir+ - _String_ - Root directory for the scenario, contains Gemfile describing dependencies.
      # * +run_dir+ - _String_ - Directory for simulation of this scenario, deleting run directory clears the scenario.
      # * +feature_file+ - _URBANopt::Core::FeatureFile_ - FeatureFile containing features to simulate.
      # * +mapper_files_dir+ - _String_ - Directory containing all mapper class files containing MapperBase definitions.
      # * +csv_file+ - _String_ - Path to CSV file assigning a MapperBase class to each feature in feature_file.
      # * +num_header_rows+ - _String_ - Number of header rows to skip in CSV file.
      def initialize(name, root_dir, run_dir, feature_file, mapper_files_dir, csv_file, num_header_rows)
        super(name, root_dir, run_dir, feature_file)
        @root_dir = root_dir
        @mapper_files_dir = mapper_files_dir
        @csv_file = csv_file
        @num_header_rows = num_header_rows

        @@logger ||= URBANopt::Scenario.logger

        load_mapper_files
      end

      # Path to CSV file
      attr_reader :csv_file #:nodoc:

      # Number of header rows to skip in CSV file
      attr_reader :num_header_rows #:nodoc:

      # Directory containing all mapper class files
      attr_reader :mapper_files_dir #:nodoc:

      # Require all simulation mappers in mapper_files_dir
      def load_mapper_files
        # loads default values from extension gem
        @options = OpenStudio::Extension::RunnerConfig.default_config(@root_dir)
        # check if runner.conf file exists
        if File.exist?(File.join(@root_dir, OpenStudio::Extension::RunnerConfig::FILENAME))
          runner_config = OpenStudio::Extension::RunnerConfig.new(@root_dir)
          # use the default values overridden with runner.conf values where not
          # nil nor empty strings
          @options = @options.merge(runner_config.options.reject{|k, v| v.nil? || (v.kind_of?(String) && v === '')})
        end

        if @options.key?(:bundle_install_path)
          puts "Bundle install path is set to: #{@options[:bundle_install_path]}"
          @options[:bundle_install_path] = Pathname(@options[:bundle_install_path]).cleanpath
          puts "Bundle adjusted path is set to: #{@options[:bundle_install_path]}"
        end
        # bundle path is assigned from the runner.conf if it exists or is assigned in the root_dir
        # if bundle install path is not provided or is empty, it will be placed in root_dir/.bundle/install, otherwise use the provided path
        bundle_path = !@options.key?(:bundle_install_path) || @options[:bundle_install_path] === '' ? (Pathname(@root_dir) / '.bundle' / 'install').realpath : @options[:bundle_install_path]
        puts "Bundle final path is set to: #{bundle_path}"

        # checks if bundle path doesn't exist or is empty
        if !Dir.exist?(bundle_path) || Dir.empty?(bundle_path)
          # install bundle
          OpenStudio::Extension::Runner.new(@root_dir)
        end

        # find all lib dirs in the bundle path and add them to the path
        lib_dirs = Dir.glob(File.join(bundle_path, '/**/lib'))
        lib_dirs.each do |ld|
          # for now only add openstudio and urbanopt gems to the load path
          # and only those with 'urbanopt' or 'openstudio' in the before-last path position
          tmp_path_arr = Pathname(ld).each_filename.to_a
          if tmp_path_arr[-2].include?('urbanopt') || tmp_path_arr[-2].include?('openstudio')
            # puts "adding DIR to load path: #{ld}"
            $LOAD_PATH.unshift(ld)
          end
        end

        dirs = Dir.glob(File.join(@mapper_files_dir, '/*.rb'))

        dirs.each do |f|
          require(f)
        rescue LoadError => e
          @@logger.error(e.message)
          raise
        end
      end

      # Gets all the simulation directories
      def simulation_dirs
        # DLM: TODO use HeaderConverters from CSV module

        rows_skipped = 0
        result = []
        CSV.foreach(@csv_file) do |row|
          if rows_skipped < @num_header_rows
            rows_skipped += 1
            next
          end

          break if row[0].nil?

          # gets +feature_id+ , +feature_name+ and +mapper_class+ from csv_file
          feature_id = row[0].chomp
          feature_name = row[1].chomp
          mapper_class = row[2].chomp

          # gets +features+ from the feature_file.
          features = []
          feature = feature_file.get_feature_by_id(feature_id)
          features << feature

          feature_names = []
          feature_names << feature_name

          simulation_dir = SimulationDirOSW.new(self, features, feature_names, mapper_class)

          result << simulation_dir
        end

        return result
      end
    end
  end
end
