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
      class Models
        # dbaas model
        class Dbaas < Instance
          attr_accessor :launch_details

          def initialize(config, state)
            super
            @launch_details = OCI::Database::Models::LaunchDbSystemDetails.new
          end

          def launch(lid)
            response = dbaas_api.launch_db_system(lid)
            instance_id = response.data.id

            dbaas_api.get_db_system(instance_id).wait_until(
              :lifecycle_state,
              OCI::Database::Models::DbSystem::LIFECYCLE_STATE_AVAILABLE,
              max_interval_seconds: 900,
              max_wait_seconds: 21600
            )
            final_state(state, instance_id)
          end

          def terminate(server_id)
            dbaas_api.terminate_db_system(server_id)
          end

          def add_specific_props
            # TODO: add support for the #domain property
            launch_details.tap do |l|
              l.cpu_core_count = cpu_core_count
              l.database_edition = database_edition
              l.db_home = create_db_home_details
              # The user-friendly name for the DB system. The name does not have to be unique.
              l.display_name = display_name
              # The hostname must begin with an alphabetic character, and can contain alphanumeric characters and hyphens (-).
              # The maximum length of the hostname is 16 characters
              l.hostname = hostname
              l.ssh_public_keys = pubkey
              l.cluster_name = generate_cluster_name
              l.initial_data_storage_size_in_gb = initial_data_storage_size_in_gb
              l.node_count = 1
              l.license_model = license_model
              l.subnet_id = config[:subnet_id]
              l.nsg_ids = config[:nsg_ids]
            end
          end

          private

          def hostname
            long_name = [hostname_prefix, long_hostname_suffix].compact.join('-')
            trimmed_name = [hostname_prefix[0, 12], random_string(3)].compact.join('-')
            [long_name, trimmed_name].min { |l, t| l.size <=> t.size }
          end

          def hostname_prefix
            config[:hostname_prefix]
          end

          def long_hostname_suffix
            [random_string(25 - hostname_prefix.length), random_string(3)].compact.join('-')
          end

          def display_name
            [config[:hostname_prefix], random_string(4), random_number(2)].compact.join('-')
          end

          def pubkey
            result = []
            result << File.readlines(config[:ssh_keypath]).first.chomp
          end

          def cpu_core_count
            config[:dbaas][:cpu_core_count] ||= 2
          end

          def database_edition
            config[:dbaas][:database_edition] ||= OCI::Database::Models::DbSystem::DATABASE_EDITION_ENTERPRISE_EDITION
          end

          def db_version
            config[:dbaas][:db_version]
          end

          def license_model
            config[:dbaas][:license_model] ||= OCI::Database::Models::DbSystem::LICENSE_MODEL_BRING_YOUR_OWN_LICENSE
          end

          def initial_data_storage_size_in_gb
            config[:dbaas][:initial_data_storage_size_in_gb] ||= 256
          end

          def create_db_home_details
            raise 'db_version cannot be nil!' if db_version.nil?

            OCI::Database::Models::CreateDbHomeDetails.new.tap do |l|
              l.database = create_database_details
              l.db_version = db_version
              l.display_name = ['dbhome', random_number(10)].compact.join
            end
          end

          def create_database_details
            OCI::Database::Models::CreateDatabaseDetails.new.tap do |l|
              l.admin_password = admin_password
              l.character_set = character_set
              l.db_name = db_name
              l.db_workload = db_workload
              l.ncharacter_set = ncharacter_set
              l.pdb_name = pdb_name
              l.db_backup_config = db_backup_config
            end
          end

          def character_set
            config[:dbaas][:character_set] ||= 'AL32UTF8'
          end

          def ncharacter_set
            config[:dbaas][:ncharacter_set] ||= 'AL16UTF16'
          end

          def db_workload
            config[:dbaas][:db_workload] ||= OCI::Database::Models::CreateDatabaseDetails::DB_WORKLOAD_OLTP
          end

          def admin_password
            config[:dbaas][:admin_password] ||= random_password(%w[# _ -])
          end

          def db_name
            config[:dbaas][:db_name] ||= 'dbaas1'
          end

          def pdb_name
            config[:dbaas][:pdb_name] ||= 'pdb001'
          end

          def db_backup_config
            OCI::Database::Models::DbBackupConfig.new.tap do |l|
              l.auto_backup_enabled = false
            end
          end

          def generate_cluster_name
            prefix = config[:hostname_prefix].split('-')[0]
            # 11 character limit for cluster_name in DBaaS
            if prefix.length >= 11
              prefix[0, 11]
            else
              [prefix, random_string(10 - prefix.length)].compact.join('-')
            end
          end

          def dbaas_node(instance_id)
            dbaas_api.list_db_nodes(
              compartment_id,
              db_system_id: instance_id
            ).data
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
