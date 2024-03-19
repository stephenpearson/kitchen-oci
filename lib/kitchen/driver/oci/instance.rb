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
        require_relative "../../driver/mixins/instance"
        require_relative "models/compute"
        require_relative "models/dbaas"

        include Kitchen::Driver::Mixins::Instance

        attr_accessor :config, :state

        def initialize(config, state)
          super()
          @config = config
          @state = state
        end

        def common_props
          compartment
          availability_domain
          defined_tags
          shape
          freeform_tags
        end

        def compartment
          launch_details.compartment_id = compartment_id
        end

        def availability_domain
          launch_details.availability_domain = config[:availability_domain]
        end

        def defined_tags
          launch_details.defined_tags = config[:defined_tags]
        end

        def shape
          launch_details.shape = config[:shape]
        end

        def freeform_tags
          launch_details.freeform_tags = process_freeform_tags
        end
      end
    end
  end
end
