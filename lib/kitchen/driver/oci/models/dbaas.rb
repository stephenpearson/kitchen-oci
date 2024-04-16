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

require_relative "../instance/dbaas"

module Kitchen
  module Driver
    class Oci
      module Models
        # dbaas model
        class Dbaas < Instance # rubocop:disable Metrics/ClassLength
          include DbaasLaunchDetails

          def initialize(config, state, oci, api, action)
            super
            @launch_details = OCI::Database::Models::LaunchDbSystemDetails.new
            @database_details = OCI::Database::Models::CreateDatabaseDetails.new
            @db_home_details = OCI::Database::Models::CreateDbHomeDetails.new
          end

          #
          # The details model that describes the db system
          #
          # @return [OCI::Database::Models::LaunchDbSystemDetails]
          #
          attr_accessor :launch_details

          #
          # The details model that describes the database
          #
          # @return [OCI::Database::Models::CreateDatabaseDetails]
          #
          attr_accessor :database_details

          #
          # The details model that describes the database home
          #
          # @return [OCI::Database::Models::CreateDbHomeDetails]
          #
          attr_accessor :db_home_details

          def launch
            response = api.dbaas.launch_db_system(launch_instance_details)
            instance_id = response.data.id

            api.dbaas.get_db_system(instance_id).wait_until(:lifecycle_state, OCI::Database::Models::DbSystem::LIFECYCLE_STATE_AVAILABLE,
                                                            max_interval_seconds: 900, max_wait_seconds: 21_600)
            final_state(state, instance_id)
          end

          def terminate
            api.dbaas.terminate_db_system(state[:server_id])
            api.dbaas.get_db_system(state[:server_id]).wait_until(:lifecycle_state, OCI::Database::Models::DbSystem::LIFECYCLE_STATE_TERMINATING,
                                                                  max_interval_seconds: 900, max_wait_seconds: 21_600)
          end

          def reboot
            db_node_id = dbaas_node(state[:server_id]).first.id
            api.dbaas.db_node_action(db_node_id, "SOFTRESET")
            api.dbaas.get_db_node(db_node_id).wait_until(:lifecycle_state, OCI::Database::Models::DbNode::LIFECYCLE_STATE_AVAILABLE)
          end

          private

          def instance_ip(instance_id)
            vnic = dbaas_node(instance_id).select(&:vnic_id).first.vnic_id
            if public_ip_allowed?
              api.network.get_vnic(vnic).data.public_ip
            else
              api.network.get_vnic(vnic).data.private_ip
            end
          end

          def dbaas_node(instance_id)
            api.dbaas.list_db_nodes(oci.compartment, db_system_id: instance_id).data
          end

          def hostname_prefix
            config[:hostname_prefix]
          end

          def long_hostname_suffix
            [random_string(25 - hostname_prefix.length), random_string(3)].compact.join("-")
          end
        end
      end
    end
  end
end
