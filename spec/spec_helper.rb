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

require "kitchen/driver/oci"
require "kitchen/provisioner/dummy"
require "kitchen/transport/dummy"
require "kitchen/verifier/dummy"

RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  #   - http://myronmars.to/n/dev-blog/2012/06/rspecs-new-expectation-syntax
  #   - http://teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  config.disable_monkey_patching!

  # This setting enables warnings. It's recommended, but in some cases may
  # be too noisy due to issues in dependencies.
  config.warnings = true

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  config.default_formatter = "doc"
  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  config.expose_dsl_globally = true
end

RSpec.shared_context "kitchen", :kitchen do
  let(:driver) { Kitchen::Driver::Oci.new(driver_config) }
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { Kitchen::Platform.new(name: "fooos-99") }
  let(:transport)     { Kitchen::Transport::Dummy.new }
  let(:provisioner)   { Kitchen::Provisioner::Dummy.new }
  let(:instance) do
    instance_double(
      Kitchen::Instance,
      name: "kitchen-foo",
      logger: logger,
      transport: transport,
      provisioner: provisioner,
      platform: platform,
      to_str: "str"
    )
  end
end

RSpec.shared_context "common", :common do
  let(:compartment_ocid) { "ocid1.compartment.oc1..aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:availability_domain) { "abCD:FAKE-AD-1" }
  let(:subnet_ocid) { "ocid1.subnet.oc1..aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:shape) { "VM.Standard2.1" }
  let(:image_ocid) { "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:ssh_pub_key) { "ssh-rsa AAABBBCCCabcdefg1234" }
  let(:hostname) { "kitchen-foo-abc123" }
  let(:hostname_prefix) { "kitchen-foo" }
  # kitchen.yml driver config section
  let(:base_driver_config) do
    {
      hostname_prefix: hostname_prefix,
      compartment_id: compartment_ocid,
      availability_domain: availability_domain,
      subnet_id: subnet_ocid,
      shape: shape,
      image_id: image_ocid,
    }
  end

  before do
    allow(File).to receive(:readlines).with(anything).and_return([ssh_pub_key])
    allow_any_instance_of(Kitchen::Driver::Oci::Blockstorage).to receive(:info)
    allow_any_instance_of(Kitchen::Driver::Oci::Config).to receive(:compartment).and_return(compartment_ocid)
    # stubbed for now. the encoding is making spec difficult right now.  plan to add specific units for the user data methods.
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:user_data).and_return("FaKeUsErDaTa")
  end
end

RSpec.shared_context "oci", :oci do
  let(:oci_config) { Kitchen::Driver::Oci::Config.new(driver_config) }
  let(:oci) { class_double(OCI::Config) }
  let(:nil_response) { OCI::Response.new(200, nil, nil) }
  let(:compute_client) { instance_double(OCI::Core::ComputeClient) }
  let(:dbaas_client) { instance_double(OCI::Database::DatabaseClient) }
  let(:net_client) { instance_double(OCI::Core::VirtualNetworkClient) }
  let(:blockstorage_client) { instance_double(OCI::Core::BlockstorageClient) }

  before do
    allow(driver).to receive(:instance).and_return(instance)
    allow(OCI::ConfigFileLoader).to receive(:load_config).and_return(oci)
  end
end

RSpec.shared_context "net", :net do
  let(:vnic_ocid) { "ocid1.vnic.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:private_ip) { "192.168.1.2" }
  let(:public_ip) { "123.456.654.321" }
  let(:cidr_block) { "192.168.1.0/24" }
  let(:vnic_attachments) do
    OCI::Response.new(200, nil, [OCI::Core::Models::VnicAttachment.new(vnic_id: vnic_ocid,
                                                                       subnet_id: subnet_ocid)])
  end
  let(:vnic) do
    OCI::Response.new(200, nil, OCI::Core::Models::Vnic.new(private_ip: private_ip,
                                                            public_ip: public_ip,
                                                            is_primary: true))
  end
  let(:subnet) do
    OCI::Response.new(200, nil, OCI::Core::Models::Subnet.new(cidr_block: cidr_block,
                                                              compartment_id: compartment_ocid,
                                                              id: subnet_ocid,
                                                              prohibit_public_ip_on_vnic: true))
  end

  before do
    allow(OCI::Core::VirtualNetworkClient).to receive(:new).with(config: oci).and_return(net_client)
    allow(net_client).to receive(:get_vnic).with(vnic_ocid).and_return(vnic)
    allow(net_client).to receive(:get_subnet).with(subnet_ocid).and_return(subnet)
  end
end

RSpec.shared_context "blockstorage", :blockstorage do
  before do
    allow(OCI::Core::BlockstorageClient).to receive(:new).with(config: oci).and_return(blockstorage_client)
    allow(pv_attachment_response).to receive(:wait_until).with(:lifecycle_state,
                                                               Lifecycle.volume_attachment("detached")).and_return(pv_attachment_response)
    allow(pv_blockstorage_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.volume("terminated")).and_return(nil_response)
    allow(blockstorage_client).to receive(:delete_volume).with(iscsi_volume_ocid).and_return(nil_response)
    allow(blockstorage_client).to receive(:delete_volume).with(pv_volume_ocid).and_return(nil_response)
    allow(iscsi_attachment_response).to receive(:wait_until).with(:lifecycle_state,
                                                                  Lifecycle.volume_attachment("detached")).and_return(iscsi_attachment_response)
    allow(iscsi_blockstorage_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.volume("terminated")).and_return(nil_response)

    allow(blockstorage_client).to receive(:create_volume).with(iscsi_volume_details).and_return(iscsi_blockstorage_response)
    allow(blockstorage_client).to receive(:get_volume).with(iscsi_volume_ocid).and_return(iscsi_blockstorage_response)
    allow(blockstorage_client).to receive(:get_volume).with(pv_volume_ocid).and_return(pv_blockstorage_response)
    allow(blockstorage_client).to receive(:create_volume).with(pv_volume_details).and_return(pv_blockstorage_response)
    allow(iscsi_blockstorage_response).to receive(:wait_until).with(:lifecycle_state,
                                                                    Lifecycle.volume("available")).and_return(iscsi_blockstorage_response)
    allow(iscsi_attachment_response).to receive(:wait_until).with(:lifecycle_state,
                                                                  Lifecycle.volume_attachment("attached")).and_return(iscsi_attachment_response)
    allow(pv_attachment_response).to receive(:wait_until).with(:lifecycle_state,
                                                               Lifecycle.volume_attachment("attached")).and_return(pv_attachment_response)
    allow(pv_blockstorage_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.volume("available")).and_return(pv_blockstorage_response)
  end
end

RSpec.shared_context "iscsi", :iscsi do
  let(:iscsi_volume_ocid) { "ocid1.volume.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:iscsi_display_name) { "vol1" }
  let(:iscsi_attachment_ocid) { "ocid1.volumeattachment.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:iscsi_attachment_display_name) { "iscsi-#{iscsi_display_name}" }
  let(:ipv4) { "1.1.2.2" }
  let(:iqn) { "iqn.2099-13.com.fake" }
  let(:port) { "3260" }
  let(:iscsi_volume_details) do
    OCI::Core::Models::CreateVolumeDetails.new(
      compartment_id: compartment_ocid,
      availability_domain: availability_domain,
      display_name: iscsi_display_name,
      size_in_gbs: 10,
      vpus_per_gb: 10
    )
  end
  let(:iscsi_attachment) do
    OCI::Core::Models::AttachIScsiVolumeDetails.new(
      display_name: iscsi_attachment_display_name,
      volume_id: iscsi_volume_ocid,
      instance_id: instance_ocid
    )
  end
end

RSpec.shared_context "paravirtual", :paravirtual do
  let(:pv_volume_ocid) { "ocid1.volume.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz67890" }
  let(:pv_attachment_ocid) { "ocid1.volumeattachment.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz67890" }
  let(:pv_display_name) { "vol2" }
  let(:pv_attachment_display_name) { "paravirtual-#{pv_display_name}" }
  let(:pv_volume_details) do
    OCI::Core::Models::CreateVolumeDetails.new(
      compartment_id: compartment_ocid,
      availability_domain: availability_domain,
      display_name: pv_display_name,
      size_in_gbs: 10,
      vpus_per_gb: 10
    )
  end
  let(:pv_attachment) do
    OCI::Core::Models::AttachParavirtualizedVolumeDetails.new(
      display_name: pv_attachment_display_name,
      volume_id: pv_volume_ocid,
      instance_id: instance_ocid
    )
  end
end

RSpec.shared_context "compute", :compute do
  include_context "common"
  include_context "kitchen"
  include_context "oci"
  include_context "net"

  let(:driver_config) { base_driver_config }
  let(:instance_ocid) { "ocid1.instance.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:instance_metadata) do
    {
      "ssh_authorized_keys" => ssh_pub_key,
    }
  end
  let(:launch_instance_request) do
    OCI::Core::Models::LaunchInstanceDetails.new.tap do |l|
      l.availability_domain = availability_domain
      l.compartment_id = compartment_ocid
      l.display_name = hostname
      l.source_details = OCI::Core::Models::InstanceSourceViaImageDetails.new(
        sourceType: "image",
        imageId: image_ocid,
        bootVolumeSizeInGBs: nil
      )
      l.shape = shape
      l.create_vnic_details = OCI::Core::Models::CreateVnicDetails.new(
        assign_public_ip: false,
        display_name: hostname,
        hostname_label: hostname,
        nsg_ids: driver_config[:nsg_ids],
        subnet_id: subnet_ocid
      )
      l.freeform_tags = { kitchen: true }
      l.defined_tags = {}
      l.metadata = instance_metadata
      l.agent_config = OCI::Core::Models::LaunchInstanceAgentConfigDetails.new(
        is_monitoring_disabled: false,
        is_management_disabled: false,
        are_all_plugins_disabled: false
      )
    end
  end

  include_context "blockstorage"
  include_context "iscsi"
  include_context "paravirtual"

  before do
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:random_string).with(6).and_return("abc123")
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:random_string).with(4).and_return("a1b2")
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:random_string).with(20).and_return("a1b2c3d4e5f6g7h8i9j0")
    allow(OCI::Core::ComputeClient).to receive(:new).with(config: oci).and_return(compute_client)
    allow(compute_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.compute("terminating"))
    allow(compute_client).to receive(:get_instance).with(instance_ocid).and_return(compute_response)
    allow(compute_client).to receive(:terminate_instance).with(instance_ocid).and_return(nil_response)
    allow(compute_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.compute("running"))
    allow(compute_client).to receive(:launch_instance).with(anything).and_return(compute_response)
    allow(compute_client).to receive(:get_instance).with(instance_ocid).and_return(compute_response)
    allow(compute_client).to receive(:list_vnic_attachments).with(compartment_ocid, instance_id: instance_ocid).and_return(vnic_attachments)
    allow(compute_client).to receive(:attach_volume).with(iscsi_attachment).and_return(iscsi_attachment_response)
    allow(compute_client).to receive(:attach_volume).with(pv_attachment).and_return(pv_attachment_response)
    allow(compute_client).to receive(:get_volume_attachment).with(iscsi_attachment_ocid).and_return(iscsi_attachment_response)
    allow(compute_client).to receive(:get_volume_attachment).with(pv_attachment_ocid).and_return(pv_attachment_response)
    allow(compute_client).to receive(:detach_volume).with(iscsi_attachment_ocid).and_return(nil_response)
    allow(compute_client).to receive(:detach_volume).with(pv_attachment_ocid).and_return(nil_response)
  end
end

RSpec.shared_context "dbaas", :dbaas do
  include_context "common"
  include_context "kitchen"
  include_context "oci"
  include_context "net"

  # kitchen.yml driver config section
  let(:driver_config) do
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
          db_backup_config: OCI::Database::Models::DbBackupConfig.new(auto_backup_enabled: false)
        ),
        db_version: driver_config[:dbaas][:db_version],
        display_name: "dbhome1029384576"
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

RSpec.shared_context "create", :create do
  let(:compute_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::Instance.new(id: instance_ocid,
                                                                lifecycle_state: Lifecycle.compute("running")))
  end
  let(:dbaas_response) do
    OCI::Response.new(200, nil, OCI::Database::Models::DbSystem.new(id: db_system_ocid, lifecycle_state: Lifecycle.dbaas("available")))
  end
  let(:db_nodes_response) do
    OCI::Response.new(200, nil, [OCI::Database::Models::DbNodeSummary.new(db_system_id: db_system_ocid,
                                                                          id: db_node_ocid,
                                                                          vnic_id: vnic_ocid)])
  end
  let(:iscsi_blockstorage_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::Volume.new(id: iscsi_volume_ocid,
                                                              display_name: iscsi_display_name,
                                                              lifecycle_state: Lifecycle.volume("available")))
  end
  let(:iscsi_attachment_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::IScsiVolumeAttachment.new(id: iscsi_attachment_ocid,
                                                                             instance_id: instance_ocid,
                                                                             volume_id: iscsi_volume_ocid,
                                                                             display_name: iscsi_attachment_display_name,
                                                                             lifecycle_state: Lifecycle.volume_attachment("attached"),
                                                                             ipv4: ipv4,
                                                                             iqn: iqn,
                                                                             port: port))
  end
  let(:pv_blockstorage_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::Volume.new(id: pv_volume_ocid,
                                                              display_name: pv_display_name,
                                                              lifecycle_state: Lifecycle.volume("available")))
  end
  let(:pv_attachment_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::ParavirtualizedVolumeAttachment.new(id: pv_attachment_ocid,
                                                                                       instance_id: instance_ocid,
                                                                                       volume_id: pv_volume_ocid,
                                                                                       display_name: pv_attachment_display_name,
                                                                                       lifecycle_state: Lifecycle.volume_attachment("attached")))
  end
  let(:list_images_response) do
    OCI::Response.new(200, nil, [
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz123456", display_name: "Oracle-Linux-9.3-2024.02.26-0", time_created: DateTime.new(2024, 2, 26, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz456789", display_name: "Oracle-Linux-9.3-2024.01.26-0", time_created: DateTime.new(2024, 1, 26, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz147852", display_name: "Oracle-Linux-9.3-aarch64-2024.02.26-0", time_created: DateTime.new(2024, 2, 26, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz258963", display_name: "Oracle-Linux-9.3-aarch64-2024.01.26-0", time_created: DateTime.new(2024, 1, 26, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz369852", display_name: "Oracle-Linux-9.3-Minimal-2024.02.29-0", time_created: DateTime.new(2024, 2, 29, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz258741", display_name: "Oracle-Linux-8.9-Gen2-GPU-2024.02.26-0", time_created: DateTime.new(2024, 2, 26, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz789654", display_name: "Oracle-Linux-8.9-aarch64-2024.02.26-0", time_created: DateTime.new(2024, 2, 26, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz456321", display_name: "Oracle-Linux-8.9-2024.02.26-0", time_created: DateTime.new(2024, 2, 26, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz145236", display_name: "Oracle-Linux-8.9-Gen2-GPU-2024.01.26-0", time_created: DateTime.new(2024, 1, 26, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz365214", display_name: "Oracle-Linux-8.9-2024.01.26-0", time_created: DateTime.new(2024, 1, 26, 18, 34, 24)),
      OCI::Core::Models::Image.new(id: "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz698547", display_name: "Oracle-Linux-8.9-aarch64-2024.01.26-0", time_created: DateTime.new(2024, 1, 26, 18, 34, 24)),
    ])
  end
end

RSpec.shared_context "destroy", :destroy do
  let(:compute_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::Instance.new(id: instance_ocid,
                                                                lifecycle_state: Lifecycle.compute("terminating")))
  end
  let(:dbaas_response) do
    OCI::Response.new(200, nil, OCI::Database::Models::DbSystem.new(id: db_system_ocid, lifecycle_state: Lifecycle.dbaas("terminating")))
  end
  let(:db_nodes_response) do
    OCI::Response.new(200, nil, [OCI::Database::Models::DbNodeSummary.new(db_system_id: db_system_ocid,
                                                                          id: db_node_ocid,
                                                                          vnic_id: vnic_ocid)])
  end
  let(:iscsi_blockstorage_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::Volume.new(id: iscsi_volume_ocid,
                                                              display_name: iscsi_display_name,
                                                              lifecycle_state: Lifecycle.volume("terminated")))
  end
  let(:iscsi_attachment_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::IScsiVolumeAttachment.new(id: iscsi_attachment_ocid,
                                                                             lifecycle_state: Lifecycle.volume_attachment("detached")))
  end
  let(:pv_blockstorage_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::Volume.new(id: pv_volume_ocid,
                                                              display_name: pv_display_name,
                                                              lifecycle_state: Lifecycle.volume("terminated")))
  end
  let(:pv_attachment_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::ParavirtualizedVolumeAttachment.new(id: pv_attachment_ocid,
                                                                                       lifecycle_state: Lifecycle.volume_attachment("detached")))
  end
end

RSpec.shared_context "proxy", :proxy do |rspec|
  before do
    stub_const("ENV", ENV.to_hash.merge({ "http_proxy" => "http://myfakeproxy.com", "no_proxy" => ".myfakedomain.com" }))
    allow(OCI::ApiClientProxySettings).to receive(:new).with("myfakeproxy.com", 80).and_return(proxy_settings)
  end
  let(:proxy_settings) { OCI::ApiClientProxySettings.new("myfakeproxy.com", 80) }
end

RSpec.shared_context "api", :common do |rspec|
  let(:oci_config) { class_double(OCI::Config) }
  let(:driver_config) { {} }
end

class Lifecycle
  def self.compute(state)
    case state
    when "running"
      OCI::Core::Models::Instance::LIFECYCLE_STATE_RUNNING
    when "terminating"
      OCI::Core::Models::Instance::LIFECYCLE_STATE_TERMINATING
    end
  end

  def self.dbaas(state)
    case state
    when "available"
      OCI::Database::Models::DbSystem::LIFECYCLE_STATE_AVAILABLE
    when "terminating"
      OCI::Database::Models::DbSystem::LIFECYCLE_STATE_TERMINATING
    end
  end

  def self.volume(state)
    case state
    when "available"
      OCI::Core::Models::Volume::LIFECYCLE_STATE_AVAILABLE
    when "terminated"
      OCI::Core::Models::Volume::LIFECYCLE_STATE_TERMINATED
    end
  end

  def self.volume_attachment(state)
    case state
    when "attached"
      OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_ATTACHED
    when "detached"
      OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_DETACHED
    end
  end
end
