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
        # Compute instance model
        class Compute < Instance # rubocop:disable Metrics/ClassLength
          include ComputeLaunchDetails

          def initialize(config, state, oci, api, action)
            super
            @launch_details = OCI::Core::Models::LaunchInstanceDetails.new
          end

          #
          # The details model that describes a compute instance
          #
          # @return [OCI::Core::Models::LaunchInstanceDetails]
          #
          attr_accessor :launch_details

          def launch
            process_windows_options
            response = api.compute.launch_instance(launch_instance_details)
            instance_id = response.data.id
            api.compute.get_instance(instance_id).wait_until(:lifecycle_state, OCI::Core::Models::Instance::LIFECYCLE_STATE_RUNNING )
            final_state(state, instance_id)
          end

          def terminate
            api.compute.terminate_instance(state[:server_id])
            api.compute.get_instance(state[:server_id]).wait_until(:lifecycle_state, OCI::Core::Models::Instance::LIFECYCLE_STATE_TERMINATING)
          end

          private

          def image_id
            return config[:image_id] if config[:image_id]

            raise "must specify either image_id or image_name" unless config[:image_name]

            image_id_by_name
          end

          def image_id_by_name
            image_name = config[:image_name].gsub(" ", "-")
            image_list = images.select { |i| i.display_name.match?(/#{image_name}/) }
            raise "unable to find image_id" if image_list.empty?

            image_list = filter_image_list(image_list, image_name) if image_list.count > 1
            raise "unable to find image_id" if image_list.empty?

            latest_image_id(image_list)
          end

          def filter_image_list(image_list, image_name)
            image_list.select { |i| i.display_name.match?(/#{image_name}-[0-9]{4}\.[0-9]{2}\.[0-9]{2}/) }
          end

          def latest_image_id(image_list)
            image_list.sort_by! { |o| ((DateTime.parse(Time.now.utc.to_s) - o.time_created) * 24 * 60 * 60).to_i }.first.id
          end

          def images(image_list = [], page = nil)
            current_images = api.compute.list_images(oci.compartment, page: page)
            next_page = current_images.next_page
            image_list << current_images.data
            images(image_list, next_page) unless next_page.nil?
            image_list.flatten
          end

          def instance_ip(instance_id)
            vnic = vnics(instance_id).select(&:is_primary).first
            if public_ip_allowed?
              config[:use_private_ip] ? vnic.private_ip : vnic.public_ip
            else
              vnic.private_ip
            end
          end

          def vnics(instance_id)
            vnic_attachments(instance_id).map { |att| api.network.get_vnic(att.vnic_id).data }
          end

          def vnic_attachments(instance_id)
            att = api.compute.list_vnic_attachments(oci.compartment, instance_id: instance_id).data
            raise "Could not find any VNIC attachments" unless att.any?

            att
          end

          def hostname
            [config[:hostname_prefix], random_string(6)].compact.join("-")
          end

          def create_vnic_details(name)
            OCI::Core::Models::CreateVnicDetails.new(
              assign_public_ip: public_ip_allowed?,
              display_name: name,
              hostname_label: name,
              nsg_ids: config[:nsg_ids],
              subnetId: config[:subnet_id]
            )
          end

          def pubkey
            File.readlines(config[:ssh_keypath]).first.chomp
          end

          def metadata
            md = {}
            inject_powershell
            config[:custom_metadata]&.each { |k, v| md.store(k, v) }
            md.store("ssh_authorized_keys", pubkey)
            md.store("user_data", user_data) if config[:user_data] && !config[:user_data].empty?
            md
          end

          def process_windows_options
            return unless windows_state?

            state.store(:username, config[:winrm_user])
            state.store(:password, config[:winrm_password] || random_password(%w{@ - ( ) .}))
          end

          def windows_state?
            config[:setup_winrm] && config[:password].nil? && state[:password].nil?
          end

          def winrm_ps1
            filename = File.join(__dir__, %w{.. .. .. .. .. tpl setup_winrm.ps1.erb})
            tpl = ERB.new(File.read(filename))
            tpl.result(binding)
          end

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
