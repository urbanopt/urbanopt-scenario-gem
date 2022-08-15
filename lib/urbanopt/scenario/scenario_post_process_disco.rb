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
                    @disco_results_dir = File.join(@scenario_report.directory_name, opendss_results_dir_name)
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
                disco_upgrade_summary = File.join(@disco_results_dir, 'upgrade_summary.json')
                if File.exist?(disco_upgrade_summary)
                    @disco_upgrade_summary = JSON.parse(File.read(disco_upgrade_summary))
                end

            end

            ##
            # save disco scenario fields
            ##
            def save_disco_scenario
                @scenario_report.scenario_power_distribution_cost = URBANopt::Reporting

            end
            
            ##
            # run disco post_processor
            ##
            def run

                # save additional global disco fields
                save_disco_scenario

                # save the updated scenario reports
                # set save_feature_reports to false since only the scenario reports should be saved now
                @scenario_report.save(file_name = 'scenario_report_opendss', save_feature_reports = false)
            end

        end
    end
end