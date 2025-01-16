# frozen_string_literal: true

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
      vpus_per_gb: 10,
      defined_tags: {}
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
