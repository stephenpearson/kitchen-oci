# frozen_string_literal: true

#
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

module Kitchen
  module Driver
    class Oci
      # generic class for instance models
      class Instance < Oci
        require_relative '../../driver/mixins/instance'
        require_relative 'models/compute'
        require_relative 'models/dbaas'

        include Kitchen::Driver::Mixins::Instance

        attr_accessor :config, :state

        def initialize(config, state)
          super()
          @config = config
          @state = state
        end

        def launch_instance
          add_common_props
          add_specific_props
          launch(launch_details)
        end

        def terminate_instance
          terminate(state[:server_id])
        end

        private

        # stuff all instances get
        def add_common_props
          launch_details.tap do |l|
            l.availability_domain = config[:availability_domain]
            l.compartment_id = compartment_id
            l.freeform_tags = freeform_tags
            l.defined_tags = config[:defined_tags]
            l.shape = config[:shape]
          end
        end
      end
    end
  end
end
