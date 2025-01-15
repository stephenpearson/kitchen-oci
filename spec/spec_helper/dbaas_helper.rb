# frozen_string_literal: true

#
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

RSpec.shared_context "dbaas", :dbaas do
  include_context "common"
  include_context "kitchen"
  include_context "oci"
  include_context "net"

  # kitchen.yml driver config section
  let(:base_dbaas_driver_config) do
    base_driver_config.merge!(
      {
        instance_type: "dbaas",
        dbaas: {
          cpu_core_count: 16,
          db_name: "dbaas1",
          pdb_name: "foo001",
          db_version: "19.0.0.0",
        },
      }
    )
  end
  let(:hostname) { "kitchen-foo-a1b" }
  let(:db_system_ocid) { "ocid1.dbsystem.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:db_node_ocid) { "ocid1.dbnode.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:db_system_launch_details) do
    OCI::Database::Models::LaunchDbSystemDetails.new.tap do |l|
      l.availability_domain = availability_domain
      l.compartment_id = compartment_ocid
      l.cpu_core_count = driver_config[:dbaas][:cpu_core_count]
      l.database_edition = OCI::Database::Models::DbSystem::DATABASE_EDITION_ENTERPRISE_EDITION
      l.db_home = OCI::Database::Models::CreateDbHomeDetails.new(
        database: OCI::Database::Models::CreateDatabaseDetails.new(
          admin_password: "5up3r53cur3!",
          character_set: "AL32UTF8",
          db_name: driver_config[:dbaas][:db_name],
          db_workload: OCI::Database::Models::CreateDatabaseDetails::DB_WORKLOAD_OLTP,
          ncharacter_set: "AL16UTF16",
          pdb_name: driver_config[:dbaas][:pdb_name],
          db_backup_config: OCI::Database::Models::DbBackupConfig.new(auto_backup_enabled: false),
          defined_tags: {}
        ),
        db_version: driver_config[:dbaas][:db_version],
        display_name: "dbhome1029384576",
        defined_tags: {}
      )
      l.display_name = "kitchen-foo-a1b2-12"
      l.hostname = hostname
      l.shape = shape
      l.ssh_public_keys = [ssh_pub_key]
      l.cluster_name = "kitchen-a1b"
      l.initial_data_storage_size_in_gb = 256
      l.node_count = 1
      l.license_model = OCI::Database::Models::DbSystem::LICENSE_MODEL_BRING_YOUR_OWN_LICENSE
      l.subnet_id = subnet_ocid
      l.nsg_ids = driver_config[:nsg_ids]
      l.freeform_tags = { kitchen: true }
      l.defined_tags = {}
    end
  end

  before do
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:random_password).and_return("5up3r53cur3!")
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:random_number).with(2).and_return(12)
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:random_number).with(10).and_return(1_029_384_576)
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:random_string).with(4).and_return("a1b2")
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:random_string).with(3).and_return("a1b")
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:random_string).with(14).and_return("a1b2c3d4e5f6g7")
    allow(OCI::Database::DatabaseClient).to receive(:new).with(config: oci).and_return(dbaas_client)
    allow(dbaas_client).to receive(:get_db_system).with(db_system_ocid).and_return(dbaas_response)
    allow(dbaas_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.dbaas("terminating"),
                                                       max_interval_seconds: 900,
                                                       max_wait_seconds: 21_600)
    allow(dbaas_client).to receive(:terminate_db_system).with(db_system_ocid).and_return(nil_response)
    allow(dbaas_client).to receive(:launch_db_system).with(anything).and_return(dbaas_response)
    allow(dbaas_client).to receive(:get_db_system).with(db_system_ocid).and_return(dbaas_response)
    allow(dbaas_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.dbaas("available"),
                                                       max_interval_seconds: 900,
                                                       max_wait_seconds: 21_600)
    allow(dbaas_client).to receive(:list_db_nodes).with(compartment_ocid, db_system_id: db_system_ocid).and_return(db_nodes_response)
  end
end
