# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'openstudio/extension'

module URBANopt
  module Scenario
    class Extension < OpenStudio::Extension::Extension
      def initialize
        super
        @root_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', '..'))
      end

      ##
      # [return:] Absolute path of the measures or nil if there is none, can be used when configuring OSWs.
      def measures_dir
        return File.absolute_path(File.join(@root_dir, 'lib', 'measures'))
      end

      ##
      # Relevant files such as weather data, design days, etc.
      ##
      # [return:] Absolute path of the files or nil if there is none, used when configuring OSWs
      def files_dir
        return nil
      end

      ##
      # Doc templates are common files like copyright files which are used to update measures and other code.
      # Doc templates will only be applied to measures in the current repository.
      ##
      # [return:] Absolute path of the doc templates dir or nil if there is none.
      def doc_templates_dir
        return File.absolute_path(File.join(@root_dir, 'doc_templates'))
      end
    end
  end
end
