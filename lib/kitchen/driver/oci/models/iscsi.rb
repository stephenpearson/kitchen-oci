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
        # iSCSI volume model.
        #
        # @author Justin Steele <justin.steele@oracle.com>
        class Iscsi < Blockstorage
          def initialize(opts = {})
            super
            @attachment_type = "iscsi"
          end

          # The type of attachment being created.
          #
          # @return [String]
          attr_reader :attachment_type

          # Creates the attachment details for an iSCSI volume.
          #
          # @param volume_details [OCI::Core::Models::Volume]
          # @param server_id [String] the ocid of the compute instance to which the volume will be attached.
          # @param volume_config [Hash] the state of the current volume being processed as specified in the kitchen.yml.
          # @return [OCI::Core::Models::AttachIScsiVolumeDetails]
          def attachment_details(volume_details, server_id, volume_config)
            device = volume_config[:device] unless server_os(server_id).downcase =~ /windows/
            OCI::Core::Models::AttachIScsiVolumeDetails.new(
              display_name: "#{attachment_type}-#{volume_details.display_name}",
              volume_id: volume_details.id,
              instance_id: server_id,
              device: device
            )
          end

          # Adds the volume attachment info into the state.
          #
          # @param response [OCI::Core::Models::VolumeAttachment]
          # @return [Hash]
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
