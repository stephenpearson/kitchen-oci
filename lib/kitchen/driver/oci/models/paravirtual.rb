# frozen_string_literal: true

module Kitchen
  module Driver
    class Oci
      class Models
        # paravirtual attachment model
        class Paravirtual < Blockstorage
          attr_reader :attachment_type

          def initialize(config, state)
            super
            @attachment_type = 'paravirtual'
          end

          def attachment_details(vol_id, server_id)
            OCI::Core::Models::AttachParavirtualizedVolumeDetails.new(
              display_name: 'paravirtAttachment',
              volume_id: vol_id,
              instance_id: server_id
            )
          end

          def final_volume_attachment_state(response)
            volume_attachment_state.store(:id, response.id)
            volume_attachment_state
          end
        end
      end
    end
  end
end
