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
    module Mixins
      # mixins common for blockstorage classes
      module Blockstorage
        require_relative 'oci_config'
        require_relative 'api'
        require_relative 'support'

        include Kitchen::Driver::Mixins::OciConfig
        include Kitchen::Driver::Mixins::Api
        include Kitchen::Driver::Mixins::Support

        attr_accessor :response

        def final_state(response)
          @response = response
          case response
          when OCI::Core::Models::Volume
            final_volume_state
          when OCI::Core::Models::VolumeAttachment
            final_volume_attachment_state(response)
          end
        end

        private

        def final_volume_state
          volume_state.store(:id, response.id)
          volume_state.store(:display_name, response.display_name)
          volume_state.store(:attachment_type, attachment_type)
          volume_state
        end
      end
    end
  end
end
