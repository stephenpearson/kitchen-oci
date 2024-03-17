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

module Kitchen
  module Driver
    class Oci
      class Blockstorage < Oci
        require_relative '../../driver/mixins/oci_config'
        require_relative '../../driver/mixins/api'
        require_relative '../../driver/mixins/support'

        include Kitchen::Driver::Mixins::OciConfig
        include Kitchen::Driver::Mixins::Api
        include Kitchen::Driver::Mixins::Support

        attr_accessor :config, :state

        def initialize(config, state)
          super()
          @config = config
          @state = state
        end

        def create_and_attach
          volume_state = { volumes: [], volume_attachments: [] }
          config[:volumes].each do |volume|
            volume_details = create_volume(volume)
            attach_details = attach_volume(volume, volume_details, state[:server_id])
            volume_state[:volumes] << volume_details
            volume_state[:volume_attachments] << attach_details
          end

          state.merge!(volume_state)
        end

        def detatch_and_delete
          state[:volume_attachments].each do |att|
            detatch_volume(att)
          end

          state[:volumes].each do |vol|
            delete_volume(vol[:id])
          end
        end

        private

        ATTACHMENT_DETAILS = {
          iscsi: {
            class: OCI::Core::Models::AttachIScsiVolumeDetails,
            display_name: 'iSCSIAttachment'
          },
          paravirtual: {
            class: OCI::Core::Models::AttachParavirtualizedVolumeDetails,
            display_name: 'paravirtAttachment'
          }
        }.freeze

        def create_volume(volume)
          info("Creating <#{volume[:name]}>...")
          vpus = volume[:vpus_per_gb] || 10
          result = blockstorage_api.create_volume(
            OCI::Core::Models::CreateVolumeDetails.new(
              compartment_id: compartment_id,
              availability_domain: config[:availability_domain],
              display_name: volume[:name],
              size_in_gbs: volume[:size_in_gbs],
              vpus_per_gb: vpus
            )
          )
          get_volume_response = blockstorage_api.get_volume(result.data.id)
                                                .wait_until(:lifecycle_state, OCI::Core::Models::Volume::LIFECYCLE_STATE_AVAILABLE)

          info("Finished creating <#{volume[:name]}>.")
          {
            id: get_volume_response.data.id,
            display_name: get_volume_response.data.display_name,
            attachment_type: volume_attachment_type(volume[:type])
          }
        end

        def volume_attachment_details(type, volume_id, server_id)
          ATTACHMENT_DETAILS[type.to_sym][:class].new(
            display_name: ATTACHMENT_DETAILS[type.to_sym][:display_name],
            volume_id: volume_id,
            instance_id: server_id
          )
        end

        def attach_volume(volume, volume_details, server_id)
          info("Attaching <#{volume_details[:display_name]}>...")
          attachment = comp_api.attach_volume(volume_attachment_details(volume_attachment_type(volume[:type]), volume_details[:id], server_id))
          get_volume_attachment_response =
            comp_api.get_volume_attachment(attachment.data.id).wait_until(:lifecycle_state,
                                                                          OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_ATTACHED)

          info("Finished attaching <#{volume_details[:display_name]}>.")

          state_data = {
            id: get_volume_attachment_response.data.id
          }

          if get_volume_attachment_response.data.attachment_type == 'iscsi'
            state_data.store(:iqn_ipv4, get_volume_attachment_response.data.ipv4)
            state_data.store(:iqn, get_volume_attachment_response.data.iqn)
            state_data.store(:port, get_volume_attachment_response.data.port)
          end
          state_data
        end

        def delete_volume(volume_id)
          info("Deleting <#{volume_id}>...")
          blockstorage_api.delete_volume(volume_id)
          blockstorage_api.get_volume(volume_id)
                          .wait_until(:lifecycle_state, OCI::Core::Models::Volume::LIFECYCLE_STATE_TERMINATED)
          info("Finished deleting <#{volume_id}>.")
        end

        def detatch_volume(volume_attachment)
          info("Detaching <#{volume_attachment[:id]}>...")
          comp_api.detach_volume(volume_attachment[:id])
          comp_api.get_volume_attachment(volume_attachment[:id])
                  .wait_until(:lifecycle_state, OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_DETACHED)
          info("Finished detaching <#{volume_attachment[:id]}>.")
        end

        def volume_attachment_type(type)
          if type.nil?
            'paravirtual'
          else
            type.downcase
          end
        end
      end
    end
  end
end
