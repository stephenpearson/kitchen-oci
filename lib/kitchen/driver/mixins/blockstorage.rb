# frozen_string_literal: true

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
