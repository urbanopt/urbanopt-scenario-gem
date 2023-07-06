# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'urbanopt/reporting'
require 'openstudio/common_measures'
require 'openstudio/model_articulation'
require 'openstudio/load_flexibility_measures'
require 'openstudio/ee_measures'
require 'openstudio/calibration'
require 'json'

module URBANopt
  module Scenario
    class TestMapper1 < SimulationMapperBase
      # class level variables
      @@instance_lock = Mutex.new
      @@osw = nil

      def initialize
        # do initialization of class variables in thread safe way
        @@instance_lock.synchronize do
          if @@osw.nil?

            # load the OSW for this class
            osw_path = File.join(File.dirname(__FILE__), 'baseline.osw')
            File.open(osw_path, 'r') do |file|
              @@osw = JSON.parse(file.read, symbolize_names: true)
            end

            # add any paths local to the project
            @@osw[:file_paths] << File.join(File.dirname(__FILE__), '../weather/')

            # configures OSW with extension gem paths for measures and files, all extension gems must be
            # required before this
            @@osw = OpenStudio::Extension.configure_osw(@@osw)
          end
        end
      end

      def create_osw(scenario, features, feature_names)
        if features.size != 1
          raise 'TestMapper1 currently cannot simulate more than one feature'
        end

        feature = features[0]

        feature_name = feature.name
        if feature_names.size == 1
          feature_name = feature_names[0]
        end

        # deep clone of @@osw before we configure it
        osw = Marshal.load(Marshal.dump(@@osw))

        # now we have the feature, we can look up its properties and set arguments in the OSW
        OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'total_bldg_floor_area', feature.area)
        OpenStudio::Extension.set_measure_argument(osw, 'add_packaged_ice_storage', '__SKIP__', false)
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_id', feature.id)
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_name', feature_name)
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_type', feature.feature_type)
        OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_location', feature.feature_location)

        osw[:name] = feature_name
        osw[:description] = feature_name

        return osw
      end
    end
  end
end
