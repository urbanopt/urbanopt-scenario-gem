# URBANopt Scenario Gem

[![Coverage Status](https://coveralls.io/repos/github/urbanopt/urbanopt-scenario-gem/badge.svg?branch=develop)](https://coveralls.io/github/urbanopt/urbanopt-scenario-gem?branch=develop)
[![nightly_build](https://github.com/urbanopt/urbanopt-scenario-gem/actions/workflows/nightly_ci_build.yml/badge.svg)](https://github.com/urbanopt/urbanopt-scenario-gem/actions/workflows/nightly_ci_build.yml)

The URBANopt&trade; Scenario Gem includes functionality for defining scenarios, running simulations, and post-processing results. User defined SimulationMapper classes translate each Feature to a SimulationDir which is a directory containing simulation input files. The ScenarioRunner is used to perform simulations for each SimulationDir. Finally, a ScenarioPostProcessor can run on a Scenario to generate scenario level results.

[RDoc Documentation](https://urbanopt.github.io/urbanopt-scenario-gem/)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'urbanopt-scenario'
```

And then execute:

    $ bundle install
    $ bundle update

Or install it yourself as:

    $ gem install 'urbanopt-scenario'

## Testing

Check out the repository and then execute:

    $ bundle install
    $ bundle update
    $ bundle exec rake

## Releasing

* Run `rake rubocop:auto_correct`
* Update version in `/lib/urbanopt/scenario/version.rb`
* On GitHub, go to the releases page and update the latest release tag (from develop). Name it “Version x.y.z”, set the previous tag to the appropriate value, and click the `Generate release notes` button
    * Copy the text generated, which is sorted according to PR labels
    * Discard the release or save as draft
* Update CHANGELOG.md appropriately, with dates and the content copied from GitHub
* Create PR to master, after tests and reviews complete, then merge
* In GitHub, make a new release or complete the previous one, basing off master/main
* Locally - from the master branch, run `rake release`
