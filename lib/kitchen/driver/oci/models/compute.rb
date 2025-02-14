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

require_relative "../instance/compute"

module Kitchen
  module Driver
    class Oci
      module Models
        # Compute instance model.
        #
        # @author Justin Steele <justin.steele@oracle.com>
        class Compute < Instance # rubocop:disable Metrics/ClassLength
          include ComputeLaunchDetails

          def initialize(opts = {})
            super
            @launch_details = OCI::Core::Models::LaunchInstanceDetails.new
          end

          # The details model that describes a compute instance.
          #
          # @return [OCI::Core::Models::LaunchInstanceDetails]
          attr_accessor :launch_details

          # Launches a compute instance.
          #
          # @return [Hash] the finalized state after the instance has been launched and is running.
          def launch
            process_windows_options
            response = api.compute.launch_instance(launch_instance_details)
            instance_id = response.data.id
            api.compute.get_instance(instance_id).wait_until(:lifecycle_state, OCI::Core::Models::Instance::LIFECYCLE_STATE_RUNNING)
            final_state(state, instance_id)
          end

          # Terminates a compute instance.
          def terminate
            api.compute.terminate_instance(state[:server_id])
            api.compute.get_instance(state[:server_id]).wait_until(:lifecycle_state, OCI::Core::Models::Instance::LIFECYCLE_STATE_TERMINATING)
          end

          # Reboots a compute instance.
          def reboot
            api.compute.instance_action(state[:server_id], "SOFTRESET")
            api.compute.get_instance(state[:server_id]).wait_until(:lifecycle_state, OCI::Core::Models::Instance::LIFECYCLE_STATE_RUNNING)
          end

          private

          # The ocid of the image to be used when creating the instance.
          # * If <b>image_id</b> is specified in the kitchen.yml, that will be returned.
          # * If <b>image_name</b> is specified in the kitchen.yml, lookup with the Compute API to find the ocid of the image by name.
          # @raise [StandardError] if neither <b>image_id</b> nor <b>image_name</b> are specified OR the image lookup by name fails to find a match.
          def image_id
            return config[:image_id] if config[:image_id]

            raise "must specify either image_id or image_name" unless config[:image_name]

            image_id_by_name
          end

          # Looks up the image ocid by name by recursively querying the list of images with the Compute API.
          #
          # @return [String] the ocid of the image.
          def image_id_by_name
            image_name = image_name_conversion
            image_list = images.select { |i| i.display_name.match(/#{image_name}/) }
            raise "unable to find image_id" if image_list.empty?

            image_list = filter_image_list(image_list, image_name) if image_list.count > 1
            raise "unable to find image_id" if image_list.empty?

            latest_image_id(image_list)
          end

          # Automatically append aarch64 to a specified image name if an ARM shape is specified.
          #
          # @return [String] the modified image name.
          def image_name_conversion
            image_name = config[:image_name].gsub(" ", "-")
            image_name = "#{image_name}-aarch64" if config[:shape] =~ /^VM\.Standard\.A\d+\.Flex$/ && !config[:image_name].include?("aarch64")
            image_name
          end

          # Filter images by name.
          #
          # @param image_list [Array] a list of the display names of all available images.
          # @param image_name [String] the image name or regular expression provided in the config.
          # @return [Array] all display names that match the image_name.
          def filter_image_list(image_list, image_name)
            image_list.select { |i| i.display_name.match(/#{image_name}-[0-9]{4}\.[0-9]{2}\.[0-9]{2}/) }
          end

          # Finds the ocid of the most recent image by time created.
          #
          # @param image_list [Array] a list of all of the display names that matched the search string.
          # @return [String] the ocid of the latest matching image.
          def latest_image_id(image_list)
            image_list.sort_by! { |o| ((DateTime.parse(Time.now.utc.to_s) - o.time_created) * 24 * 60 * 60).to_i }.first.id
          end

          # Pages through all of the images in the compartment. This has to be a recursive process because the list_images API only returns 99 entries at a time.
          #
          # @return [Array] An array of OCI::Core::Models::Image.
          def images(image_list = [], page = nil)
            current_images = api.compute.list_images(oci.compartment, page: page)
            next_page = current_images.next_page
            image_list << current_images.data
            images(image_list, next_page) unless next_page.nil?
            image_list.flatten
          end

          # Clone the specified boot volume and return the new ocid.
          #
          # @return [String]
          def clone_boot_volume
            logger.info("Cloning boot volume...")
            cbv = api.blockstorage.create_boot_volume(clone_boot_volume_details)
            api.blockstorage.get_boot_volume(cbv.data.id).wait_until(:lifecycle_state, OCI::Core::Models::BootVolume::LIFECYCLE_STATE_AVAILABLE)
            logger.info("Finished cloning boot volume.")
            cbv.data.id
          end

          # Create a new instance of OCI::Core::Models::CreateBootVolumeDetails.
          #
          # @return [OCI::Core::Models::CreateBootVolumeDetails]
          def clone_boot_volume_details
            OCI::Core::Models::CreateBootVolumeDetails.new(
              source_details: OCI::Core::Models::BootVolumeSourceFromBootVolumeDetails.new(
                id: config[:boot_volume_id]
              ),
              display_name: boot_volume_display_name,
              compartment_id: oci.compartment,
              defined_tags: config[:defined_tags]
            )
          end

          # Create the display name of the cloned boot volume.
          #
          # @return [String]
          def boot_volume_display_name
            "#{api.blockstorage.get_boot_volume(config[:boot_volume_id]).data.display_name} (Clone)"
          end

          # Get the IP address of the instance from the vnic.
          #
          # @param instance_id [String] the ocid of the instance.
          # @return [String]
          def instance_ip(instance_id)
            vnic = vnics(instance_id).select(&:is_primary).first
            if public_ip_allowed?
              config[:use_private_ip] ? vnic.private_ip : vnic.public_ip
            else
              vnic.private_ip
            end
          end

          # Get a list of all vnics attached to the instance.
          #
          # @param instance_id [String] the ocid of the instance.
          # @return [Array] a list of OCI::Core::Models::Vnic.
          def vnics(instance_id)
            vnic_attachments(instance_id).map { |att| api.network.get_vnic(att.vnic_id).data }
          end

          # Get a list of all vnic attachments associated with the instance.
          #
          # @param instance_id [String] the ocid of the instance.
          # @return [Array] a list of OCI::Core::Models::VnicAttachment.
          def vnic_attachments(instance_id)
            att = api.compute.list_vnic_attachments(oci.compartment, instance_id: instance_id).data
            raise "Could not find any VNIC attachments" unless att.any?

            att
          end

          # Generate a hostname that includes some randomness.
          #
          # @return [String]
          def hostname
            %W{#{config[:hostname_prefix]} #{config[:instance_name]} #{random_string(6)}}.uniq.compact.join("-")
          end

          # Create the details of the vnic that will be created.
          #
          # @param name [String] the display name of the instance being created.
          def create_vnic_details(name)
            OCI::Core::Models::CreateVnicDetails.new(
              assign_public_ip: public_ip_allowed?,
              display_name: name,
              hostname_label: name,
              nsg_ids: config[:nsg_ids],
              subnetId: config[:subnet_id]
            )
          end

          # Read in the public ssh key.
          #
          # @return [String]
          def pubkey
            if config[:ssh_keygen]
              logger.info("Generating public/private rsa key pair")
              gen_key_pair
            end
            File.readlines(public_key_file).first.chomp
          end

          # Add our special sauce to the instance metadata to be executed by cloud_init.
          def metadata
            md = {}
            inject_powershell
            config[:custom_metadata]&.each { |k, v| md.store(k, v) }
            md.store("ssh_authorized_keys", pubkey) unless config[:setup_winrm]
            md.store("user_data", user_data) if user_data?
            md
          end

          # Piece together options that a required for Windows instances.
          def process_windows_options
            return unless windows_state?

            state.store(:username, config[:winrm_user])
            state.store(:password, config[:winrm_password] || random_password(%w{@ - ( ) .}))
          end

          # Do the windows-y things exist in the kitchen config or the state?
          #
          # @return [Boolean]
          def windows_state?
            config[:setup_winrm] && config[:password].nil? && state[:password].nil?
          end

          # Has custom user_data been provided in the config?
          #
          # @return [Boolean]
          def user_data?
            config[:user_data] && !config[:user_data].empty?
          end

          # Read in and bind our winrm setup script.
          #
          # @return [String]
          def winrm_ps1
            filename = File.join(__dir__, %w{.. .. .. .. .. tpl setup_winrm.ps1.erb})
            tpl = ERB.new(File.read(filename))
            tpl.result(binding)
          end

          # Inject all of the winrm setup stuff into cloud_init.
          #
          # @return [Hash] the user_data config hash with the winrm stuff injected.
          def inject_powershell
            return unless config[:setup_winrm]

            data = winrm_ps1
            config[:user_data] ||= []
            config[:user_data] << {
              type: "x-shellscript",
              inline: data,
              filename: "setup_winrm.ps1",
            }
          end
        end
      end
    end
  end
end
