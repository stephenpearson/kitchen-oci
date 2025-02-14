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
      class Instance
        # Setter methods that populate the details of OCI::Database::Models::CreateDatabaseDetails.
        #
        # @author Justin Steele <justin.steele@oracle.com>
        module DatabaseDetails
          # Adds the database_software_image_id property to the database_details if provided.
          def database_software_image
            return unless config[:dbaas][:db_software_image_id]

            database_details.database_software_image_id = config[:dbaas][:db_software_image_id]
          end

          # Adds the character_set property to the database_details.
          def character_set
            database_details.character_set = config[:dbaas][:character_set] ||= "AL32UTF8"
          end

          # Adds the ncharacter_set property to the database_details.
          def ncharacter_set
            database_details.ncharacter_set = config[:dbaas][:ncharacter_set] ||= "AL16UTF16"
          end

          # Adds the db_workload property to the database details.
          def db_workload
            workload = config[:dbaas][:db_workload] ||= OCI::Database::Models::CreateDatabaseDetails::DB_WORKLOAD_OLTP
            database_details.db_workload = workload
          end

          # Adds the admin_password property to the database details.
          def admin_password
            database_details.admin_password = config[:dbaas][:admin_password] ||= random_password(%w{# _ -})
          end

          # Adds the db_name property to the database_details.
          def db_name
            database_details.db_name = config[:dbaas][:db_name] ||= "dbaas1"
          end

          # Adds the pdb_name property to the database_details.
          def pdb_name
            database_details.pdb_name = config[:dbaas][:pdb_name]
          end

          # Adds the db_backup_config property to the database_details by creating a new instance of OCI::Database::Models::DbBackupConfig.
          def db_backup_config
            database_details.db_backup_config = OCI::Database::Models::DbBackupConfig.new.tap do |l|
              l.auto_backup_enabled = false
            end
            database_details
          end

          # Adds the defined tags property to the database_details.
          def db_defined_tags
            database_details.defined_tags = config[:defined_tags]
          end
        end
      end
    end
  end
end
