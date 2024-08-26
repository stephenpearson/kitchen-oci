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
      module Models
        # iscsi volume attachment model
        class Iscsi < Blockstorage
          def initialize(config, state, oci, api)
            super
            @attachment_type = "iscsi"
          end

          #
          # The type of attachment being created
          #
          # @return [String]
          #
          attr_reader :attachment_type

          def attachment_details(volume_details, server_id, volume_config)
            device = volume_config[:device] unless server_os(server_id).downcase =~ /windows/
            OCI::Core::Models::AttachIScsiVolumeDetails.new(
              display_name: "#{attachment_type}-#{volume_details.display_name}",
              volume_id: volume_details.id,
              instance_id: server_id,
              device: device
            )
          end

          def final_volume_attachment_state(response)
            volume_attachment_state.store(:id, response.id)
            volume_attachment_state.store(:display_name, response.display_name)
            volume_attachment_state.store(:iqn_ipv4, response.ipv4)
            volume_attachment_state.store(:iqn, response.iqn)
            volume_attachment_state.store(:port, response.port)
            volume_attachment_state
          end
        end
      end
    end
  end
end
