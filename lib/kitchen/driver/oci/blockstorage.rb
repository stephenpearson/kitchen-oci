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
      # Base class for blockstorage models.
      #
      # @author Justin Steele <justin.steele@oracle.com>
      class Blockstorage < Oci # rubocop:disable Metrics/ClassLength
        require_relative "api"
        require_relative "config"
        require_relative "models/iscsi"
        require_relative "models/paravirtual"

        def initialize(opts = {})
          super()
          @config = opts[:config]
          @state = opts[:state]
          @oci = opts[:oci]
          @api = opts[:api]
          @logger = opts[:logger]
          @volume_state = {}
          @volume_attachment_state = {}
          oci.compartment if opts[:action] == :create
        end

        # The config provided by the driver.
        #
        # @return [Kitchen::LazyHash]
        attr_accessor :config

        # The definition of the state of the instance from the statefile.
        #
        # @return [Hash]
        attr_accessor :state

        # The config object that contains properties of the authentication to OCI.
        #
        # @return [Kitchen::Driver::Oci::Config]
        attr_accessor :oci

        # The API object that contains each of the authenticated clients for interfacing with OCI.
        #
        # @return [Kitchen::Driver::Oci::Api]
        attr_accessor :api

        # The instance of Kitchen::Logger in use by the active Kitchen::Instance.
        #
        # @return [Kitchen::Logger]
        attr_accessor :logger

        # The definition of the state of a volume.
        #
        # @return [Hash]
        attr_accessor :volume_state

        # The definition of the state of a volume attachment.
        #
        # @return [Hash]
        attr_accessor :volume_attachment_state

        # Create the volume as specified in the kitchen config.
        #
        # @param volume [Hash] the state of the current volume being created.
        # @return [Array(OCI::Core::Models::Volume, Hash)] returns the actual volume response from OCI for the created volume and the state hash.
        def create_volume(volume)
          logger.info("Creating <#{volume[:name]}>...")
          result = api.blockstorage.create_volume(volume_details(volume))
          response = volume_response(result.data.id)
          logger.info("Finished creating <#{volume[:name]}>.")
          [response, final_state(response)]
        end

        # Clones the specified volume.
        #
        # @param volume [Hash] the state of the current volume being cloned.
        # @return [Array(OCI::Core::Models::Volume, Hash)] returns the actual volume response from OCI for the cloned volume and the state hash.
        def create_clone_volume(volume)
          clone_volume_name = clone_volume_display_name(volume[:volume_id])
          logger.info("Creating <#{clone_volume_name}>...")
          result = api.blockstorage.create_volume(volume_clone_details(volume, clone_volume_name))
          response = volume_response(result.data.id)
          logger.info("Finished creating <#{clone_volume_name}>.")
          [response, final_state(response)]
        end

        # Attaches the volume to the instance.
        #
        # @param volume_details [OCI::Core::Models::Volume]
        # @param server_id [String] the ocid of the compute instance we are attaching the volume to.
        # @return [Hash] the updated state hash.
        def attach_volume(volume_details, server_id, volume_config)
          logger.info("Attaching <#{volume_details.display_name}>...")
          attach_volume = api.compute.attach_volume(attachment_details(volume_details, server_id, volume_config))
          response = attachment_response(attach_volume.data.id)
          logger.info("Finished attaching <#{volume_details.display_name}>.")
          final_state(response)
        end

        # Deletes the specified volume.
        #
        # @param volume [Hash] the state of the current volume being deleted from the state file.
        def delete_volume(volume)
          logger.info("Deleting <#{volume[:display_name]}>...")
          api.blockstorage.delete_volume(volume[:id])
          api.blockstorage.get_volume(volume[:id])
            .wait_until(:lifecycle_state, OCI::Core::Models::Volume::LIFECYCLE_STATE_TERMINATED)
          logger.info("Finished deleting <#{volume[:display_name]}>.")
        end

        # Detaches the specified volume.
        #
        # @param volume_attachment [Hash] the state of the current volume being deleted from the state file.
        def detatch_volume(volume_attachment)
          logger.info("Detaching <#{attachment_name(volume_attachment)}>...")
          api.compute.detach_volume(volume_attachment[:id])
          api.compute.get_volume_attachment(volume_attachment[:id])
            .wait_until(:lifecycle_state, OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_DETACHED)
          logger.info("Finished detaching <#{attachment_name(volume_attachment)}>.")
        end

        # Adds the volume and attachment info into the state.
        #
        # @param response [OCI::Core::Models::Volume, OCI::Core::Models::VolumeAttachment] The response from volume creation or attachment.
        # @return [Hash]
        def final_state(response)
          case response
          when OCI::Core::Models::Volume
            final_volume_state(response)
          when OCI::Core::Models::VolumeAttachment
            final_volume_attachment_state(response)
          end
        end

        private

        # The response from creating a volume.
        #
        # @return [OCI::Core::Models::Volume]
        def volume_response(volume_id)
          api.blockstorage.get_volume(volume_id)
            .wait_until(:lifecycle_state, OCI::Core::Models::Volume::LIFECYCLE_STATE_AVAILABLE).data
        end

        # The response from attaching a volume.
        #
        # @return [OCI::Core::Models::VolumeAttachment]
        def attachment_response(attachment_id)
          api.compute.get_volume_attachment(attachment_id)
            .wait_until(:lifecycle_state, OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_ATTACHED).data
        end

        # The details of the volume that is being created.
        #
        # @param volume [Hash] the state of the current volume being created.
        # @return [OCI::Core::Models::CreateVolumeDetails]
        def volume_details(volume)
          OCI::Core::Models::CreateVolumeDetails.new(
            compartment_id: oci.compartment,
            availability_domain: config[:availability_domain],
            display_name: volume[:name],
            size_in_gbs: volume[:size_in_gbs],
            vpus_per_gb: volume[:vpus_per_gb] || 10,
            defined_tags: config[:defined_tags]
          )
        end

        # The details of a volume that is being created as a clone of an existing volume.
        #
        # @param volume [Hash] the state of the current volume being cloned.
        # @param clone_volume_name [String] the desired name of the new volume.
        # @return [OCI::Core::Models::CreateVolumeDetails]
        def volume_clone_details(volume, clone_volume_name)
          OCI::Core::Models::CreateVolumeDetails.new(
            compartment_id: oci.compartment,
            availability_domain: config[:availability_domain],
            display_name: clone_volume_name,
            defined_tags: config[:defined_tags],
            size_in_gbs: volume[:size_in_gbs],
            vpus_per_gb: volume[:vpus_per_gb],
            source_details: OCI::Core::Models::VolumeSourceFromVolumeDetails.new(id: volume[:volume_id])
          )
        end

        # Returns a somewhat prettier display name for the volume attachment.
        #
        # @param attachment [Hash] the state of the current volume attachment being created.
        # @return [String]
        def attachment_name(attachment)
          attachment[:display_name].gsub(/(?:paravirtual|iscsi)-/, "")
        end

        # Returns the operating system from the instance.
        #
        # @param server_id [String] the ocid of the compute instance.
        # @return [String]
        def server_os(server_id)
          image_id = api.compute.get_instance(server_id).data.image_id
          api.compute.get_image(image_id).data.operating_system
        end

        # Adds the ocid and display name of the volume to the state.
        #
        # @param response [OCI::Core::Models::Volume]
        # @return [Hash]
        def final_volume_state(response)
          volume_state.store(:id, response.id)
          volume_state.store(:display_name, response.display_name)
          volume_state
        end

        # Appends the (Clone) string to the display name of the block volume that is being cloned.
        #
        # @param volume_id [String] the ocid of the volume being cloned.
        # @return [String] the display name of the cloned volume.
        def clone_volume_display_name(volume_id)
          "#{api.blockstorage.get_volume(volume_id).data.to_hash[:displayName]} (Clone)"
        end
      end
    end
  end
end
