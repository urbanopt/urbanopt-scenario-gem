# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'urbanopt/core/feature'
require 'urbanopt/core/feature_file'

class ExampleFeature < URBANopt::Core::Feature
  def initialize(json)
    super()
    @id = json[:id]
    @name = json[:name]
    @json = json
  end

  def area
    @json[:area]
  end

  def feature_type
    'Building'
  end

  def feature_location
    # take just 1 vertex here for testing
    (@json[:geometry][:coordinates][0][1]).to_s
  end
end

# Simple example of a FeatureFile
class ExampleFeatureFile < URBANopt::Core::FeatureFile
  def initialize(path)
    super()

    @path = path

    @json = nil
    File.open(path, 'r') do |file|
      @json = JSON.parse(file.read, symbolize_names: true)
    end

    @features = []
    @json[:buildings].each do |building|
      @features << ExampleFeature.new(building)
    end
  end

  attr_reader :path

  def features
    result = []
    @features
  end

  def get_feature_by_id(id)
    @features.each do |f|
      if f.id == id
        return f
      end
    end
    return nil
  end
end
