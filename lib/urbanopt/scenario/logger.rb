# *********************************************************************************
# URBANopt (tm), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-scenario-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'logger'

module URBANopt
  module Scenario
    @@logger = Logger.new($stdout)

    # Defining class variable "@@logger" to log errors, info and warning messages.
    def self.logger
      @@logger
    end
  end
end
