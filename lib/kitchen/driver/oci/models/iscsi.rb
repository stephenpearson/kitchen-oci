# frozen_string_literal: true

module Kitchen
  module Driver
    class Oci
      class Models
        # iscsi volume attachment model
        class Iscsi < Blockstorage
          attr_reader :attachment_type

          def initialize(config, state)
            super
            @attachment_type = 'iscsi'
          end

          def attachment_details(vol_id, server_id)
            OCI::Core::Models::AttachIScsiVolumeDetails.new(
              display_name: 'iSCSIAttachment',
              volume_id: vol_id,
              instance_id: server_id
            )
          end

          def final_volume_attachment_state(response)
            volume_attachment_state.store(:id, response.id)
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
