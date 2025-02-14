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
        # Setter methods that populate the details of OCI::Database::Models::CreateDbHomeDetails.
        #
        # @author Justin Steele <justin.steele@oracle.com>
        module DbHomeDetails
          # Adds the database property to the db_home_details.
          def database
            db_home_details.database = database_details
          end

          # Adds the db_version property to the db_home_details.
          # @raise [StandardError] if a version has not been provided.
          def db_version
            raise "db_version cannot be nil!" if config[:dbaas][:db_version].nil?

            db_home_details.db_version = config[:dbaas][:db_version]
          end

          # Adds the display_name property to db_home_details.
          def db_home_display_name
            db_home_details.display_name = ["dbhome", random_number(10)].compact.join
          end

          # Adds the database_software_image_id to the db_home_details.
          def db_home_software_image
            return unless config[:dbaas][:db_software_image_id]

            db_home_details.database_software_image_id = config[:dbaas][:db_software_image_id]
          end

          # Adds the defined_tags to the db_home_details.
          def db_home_defined_tags
            db_home_details.defined_tags = config[:defined_tags]
          end
        end
      end
    end
  end
end
