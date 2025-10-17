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

require_relative "../instance/database"
require_relative "../instance/db_home"

module Kitchen
  module Driver
    class Oci
      class Instance
        # Setter methods that populate the details of OCI::Database::Models::LaunchDbSystemDetails.
        #
        # @author Justin Steele <justin.steele@oracle.com>
        module DbaasLaunchDetails
          include DatabaseDetails
          include DbHomeDetails
          #
          # TODO: add support for the #domain property
          #

          # Adds the db_home property to the launch_details.
          def db_home
            launch_details.db_home = db_home_details
          end

          # Adds the subnet_id property to the launch_details.
          def subnet_id
            launch_details.subnet_id = config[:subnet_id]
          end

          # Adds the nsg_ids property to the launch_details.
          def nsg_ids
            launch_details.nsg_ids = config[:nsg_ids]
          end

          # Adds the hostname property to the launch_details.
          # The hostname must begin with an alphabetic character, and can contain alphanumeric characters and hyphens (-).
          # The maximum length of the hostname is 16 characters.
          def hostname
            long_name = [hostname_prefix, long_hostname_suffix].compact.join("-")
            trimmed_name = [hostname_prefix[0, 12], random_string(3)].compact.join("-")
            launch_details.hostname = [long_name, trimmed_name].min { |l, t| l.size <=> t.size }
          end

          # Adds the display_name property to the launch details.
          # The user-friendly name for the DB system. The name does not have to be unique.
          def display_name
            launch_details.display_name = [config[:hostname_prefix], random_string(4), random_number(2)].compact.join("-")
          end

          # Adds the node_count property to the launch_details.
          def node_count
            launch_details.node_count = 1
          end

          # Adds the ssh_public_keys property to the launch_details.
          def ssh_public_keys
            result = []
            result << read_public_key
            launch_details.ssh_public_keys = result
          end

          # Adds the cpu_core_count property to the launch_details.
          def cpu_core_count
            launch_details.cpu_core_count = config[:dbaas][:cpu_core_count] ||= 2
          end

          # Adds the license_model property to the launch_details.
          def license_model
            license = config[:dbaas][:license_model] ||= OCI::Database::Models::DbSystem::LICENSE_MODEL_BRING_YOUR_OWN_LICENSE
            launch_details.license_model = license
          end

          # Adds the initial_data_size_in_gb property to the launch_details.
          def initial_data_storage_size_in_gb
            launch_details.initial_data_storage_size_in_gb = config[:dbaas][:initial_data_storage_size_in_gb] ||= 256
          end

          # Adds the database_edition property to the launch_details.
          def database_edition
            db_edition = config[:dbaas][:database_edition] ||= OCI::Database::Models::DbSystem::DATABASE_EDITION_ENTERPRISE_EDITION
            launch_details.database_edition = db_edition
          end

          # Adds the cluster_name property to the launch_details.
          # 11 character limit for cluster_name in DBaaS.
          def cluster_name
            prefix = config[:hostname_prefix].split("-")[0]

            cn = if prefix.length >= 11
                   prefix[0, 11]
                 else
                   [prefix, random_string(10 - prefix.length)].compact.join("-")
                 end
            launch_details.cluster_name = cn
          end
        end
      end
    end
  end
end
