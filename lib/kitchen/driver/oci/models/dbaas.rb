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
      module Models
        # dbaas model
        class Dbaas < Instance
          require_relative "dbaas/database"

          include Dbaas::Database

          attr_accessor :launch_details, :database_details, :db_home_details

          def initialize(config, state)
            super
            @launch_details = OCI::Database::Models::LaunchDbSystemDetails.new
            @database_details = OCI::Database::Models::CreateDatabaseDetails.new
            @db_home_details = OCI::Database::Models::CreateDbHomeDetails.new
          end

          def launch
            response = dbaas_api.launch_db_system(launch_instance_details)
            instance_id = response.data.id

            dbaas_api.get_db_system(instance_id).wait_until(:lifecycle_state, OCI::Database::Models::DbSystem::LIFECYCLE_STATE_AVAILABLE,
                                                            max_interval_seconds: 900, max_wait_seconds: 21_600)
            final_state(state, instance_id)
          end

          def terminate
            dbaas_api.terminate_db_system(state[:server_id])
          end

          private

          def launch_instance_details # rubocop:disable Metrics/MethodLength
            # TODO: add support for the #domain property
            common_props
            names
            cpu_core_count
            create_db_home_details
            subnet_id
            nsg_ids
            pubkey
            initial_data_storage_size_in_gb
            node_count
            license_model
            launch_details
          end

          def subnet_id
            launch_details.subnet_id = config[:subnet_id]
          end

          def nsg_ids
            launch_details.nsg_ids = config[:nsg_ids]
          end

          def names
            hostname
            display_name
            launch_details
          end

          def hostname
            # The hostname must begin with an alphabetic character, and can contain alphanumeric characters and hyphens (-).
            # The maximum length of the hostname is 16 characters
            long_name = [hostname_prefix, long_hostname_suffix].compact.join("-")
            trimmed_name = [hostname_prefix[0, 12], random_string(3)].compact.join("-")
            launch_details.hostname = [long_name, trimmed_name].min { |l, t| l.size <=> t.size }
          end

          def display_name
            # The user-friendly name for the DB system. The name does not have to be unique.
            launch_details.display_name = [config[:hostname_prefix], random_string(4), random_number(2)].compact.join("-")
          end

          def hostname_prefix
            config[:hostname_prefix]
          end

          def node_count
            launch_details.node_count = 1
          end

          def long_hostname_suffix
            [random_string(25 - hostname_prefix.length), random_string(3)].compact.join("-")
          end

          def pubkey
            result = []
            result << File.readlines(config[:ssh_keypath]).first.chomp
            launch_details.ssh_public_keys = result
          end

          def cpu_core_count
            launch_details.cpu_core_count = config[:dbaas][:cpu_core_count] ||= 2
          end

          def license_model
            license = config[:dbaas][:license_model] ||= OCI::Database::Models::DbSystem::LICENSE_MODEL_BRING_YOUR_OWN_LICENSE
            launch_details.license_model = license
          end

          def initial_data_storage_size_in_gb
            launch_details.initial_data_storage_size_in_gb = config[:dbaas][:initial_data_storage_size_in_gb] ||= 256
          end

          def dbaas_node(instance_id)
            dbaas_api.list_db_nodes(compartment_id, db_system_id: instance_id).data
          end

          def dbaas_vnic(node_ocid)
            dbaas_api.get_db_node(node_ocid).data
          end

          def instance_ip(instance_id)
            vnic = dbaas_node(instance_id).select(&:vnic_id).first.vnic_id
            if public_ip_allowed?
              net_api.get_vnic(vnic).data.public_ip
            else
              net_api.get_vnic(vnic).data.private_ip
            end
          end
        end
      end
    end
  end
end
