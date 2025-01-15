# frozen_string_literal: true

RSpec.shared_context "compute", :compute do
  include_context "common"
  include_context "kitchen"
  include_context "oci"
  include_context "net"

  let(:compute_driver_config) { base_driver_config.merge!({ capacity_reservation_id: capacity_reservation }) }
  let(:instance_ocid) { "ocid1.instance.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:instance_metadata) do
    {
      "ssh_authorized_keys" => ssh_pub_key,
    }
  end
  let(:capacity_reservation) { "ocid1.capacityreservation.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
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
      l.capacity_reservation_id = capacity_reservation
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

  let(:launch_instance_from_bv_request) do
    OCI::Core::Models::LaunchInstanceDetails.new.tap do |l|
      l.availability_domain = availability_domain
      l.compartment_id = compartment_ocid
      l.display_name = hostname
      l.source_details = OCI::Core::Models::InstanceSourceViaBootVolumeDetails.new(
        sourceType: "bootVolume",
        boot_volume_id: clone_boot_volume_ocid
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
