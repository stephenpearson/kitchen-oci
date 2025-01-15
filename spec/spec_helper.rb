# frozen_string_literal: true

# Author:: Justin Steele (<justin.steele@oracle.com>)
#
# Copyright (C) 2024, Stephen Pearson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "kitchen/driver/oci"
require "kitchen/provisioner/dummy"
require "kitchen/transport/dummy"
require "kitchen/verifier/dummy"

RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  #   - http://myronmars.to/n/dev-blog/2012/06/rspecs-new-expectation-syntax
  #   - http://teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  config.disable_monkey_patching!

  # This setting enables warnings. It's recommended, but in some cases may
  # be too noisy due to issues in dependencies.
  config.warnings = true

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  config.default_formatter = "doc"
  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  config.expose_dsl_globally = true
end

require "spec_helper/kitchen_helper"
require "spec_helper/common_helper"
require "spec_helper/oci_helper"
require "spec_helper/net_helper"
require "spec_helper/blockstorage_helper"
require "spec_helper/iscsi_helper"
require "spec_helper/paravirtual_helper"
require "spec_helper/compute_helper"
require "spec_helper/dbaas_helper"
require "spec_helper/create_helper"
require "spec_helper/destroy_helper"
require "spec_helper/proxy_helper"
require "spec_helper/api_helper"

class Lifecycle
  def self.compute(state)
    case state
    when "running"
      OCI::Core::Models::Instance::LIFECYCLE_STATE_RUNNING
    when "terminating"
      OCI::Core::Models::Instance::LIFECYCLE_STATE_TERMINATING
    end
  end

  def self.dbaas(state)
    case state
    when "available"
      OCI::Database::Models::DbSystem::LIFECYCLE_STATE_AVAILABLE
    when "terminating"
      OCI::Database::Models::DbSystem::LIFECYCLE_STATE_TERMINATING
    end
  end

  def self.volume(state)
    case state
    when "available"
      OCI::Core::Models::Volume::LIFECYCLE_STATE_AVAILABLE
    when "terminated"
      OCI::Core::Models::Volume::LIFECYCLE_STATE_TERMINATED
    end
  end

  def self.volume_attachment(state)
    case state
    when "attached"
      OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_ATTACHED
    when "detached"
      OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_DETACHED
    end
  end
end
