
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'urbanopt/scenario/version'

Gem::Specification.new do |spec|
  spec.name          = 'urbanopt-scenario'
  spec.version       = URBANopt::Scenario::VERSION
  spec.authors       = ['Rawad El Kontar', 'Dan Macumber']
  spec.email         = ['rawad.elkontar@nrel.gov']

  spec.summary       = 'Library to export data point OSW files from URBANopt Scenario CSV'
  spec.description   = 'Library to export data point OSW files from URBANopt Scenario CSV'
  spec.homepage      = 'https://github.com/urbanopt'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '~> 2.2.4'

  #   use specific versions of these dependencies while using Ruby 2.2
  spec.add_development_dependency "rack", "2.1.2"
  spec.add_dependency 'public_suffix', '3.1.1'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '12.3'
  spec.add_development_dependency 'rspec', '3.7'
  spec.add_development_dependency 'github_api', '~> 0.18.0'  

  spec.add_dependency 'json-schema'
  spec.add_dependency 'json_pure'
  spec.add_dependency 'openstudio-model-articulation', '~> 0.1.1'
  spec.add_dependency 'urbanopt-core', '~> 0.1.0'
end
