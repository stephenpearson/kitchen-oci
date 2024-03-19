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
        class Dbaas
          # database specific properties
          module Database
            def create_db_home_details
              db_version
              db_home_display_name
              database_edition
              db_home_details.database = create_database_details
              launch_details.db_home = db_home_details
            end

            def create_database_details
              cluster_name
              db_name
              pdb_name
              admin_password
              character_set
              db_workload
              ncharacter_set
              db_backup_config
            end

            def db_version
              raise "db_version cannot be nil!" if config[:dbaas][:db_version].nil?

              db_home_details.db_version = config[:dbaas][:db_version]
            end

            def db_home_display_name
              db_home_details.display_name = ["dbhome", random_number(10)].compact.join
            end

            def character_set
              database_details.character_set = config[:dbaas][:character_set] ||= "AL32UTF8"
            end

            def ncharacter_set
              database_details.ncharacter_set = config[:dbaas][:ncharacter_set] ||= "AL16UTF16"
            end

            def db_workload
              workload = config[:dbaas][:db_workload] ||= OCI::Database::Models::CreateDatabaseDetails::DB_WORKLOAD_OLTP
              database_details.db_workload = workload
            end

            def admin_password
              database_details.admin_password = config[:dbaas][:admin_password] ||= random_password(%w{# _ -})
            end

            def db_name
              database_details.db_name = config[:dbaas][:db_name] ||= "dbaas1"
            end

            def pdb_name
              database_details.pdb_name = config[:dbaas][:pdb_name] ||= "pdb001"
            end

            def db_backup_config
              database_details.db_backup_config = OCI::Database::Models::DbBackupConfig.new.tap do |l|
                l.auto_backup_enabled = false
              end
              database_details
            end

            def database_edition
              db_edition = config[:dbaas][:database_edition] ||= OCI::Database::Models::DbSystem::DATABASE_EDITION_ENTERPRISE_EDITION
              launch_details.database_edition = db_edition
            end

            def cluster_name
              prefix = config[:hostname_prefix].split("-")[0]
              # 11 character limit for cluster_name in DBaaS
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
end
