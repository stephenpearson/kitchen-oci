# frozen_string_literal: true

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
      vpus_per_gb: 10,
      defined_tags: {}
    )
  end
  let(:windows_pv_attachment) do
    OCI::Core::Models::AttachParavirtualizedVolumeDetails.new(
      display_name: pv_attachment_display_name,
      volume_id: pv_volume_ocid,
      instance_id: instance_ocid
    )
  end
  let(:pv_attachment) do
    OCI::Core::Models::AttachParavirtualizedVolumeDetails.new(
      display_name: pv_attachment_display_name,
      volume_id: pv_volume_ocid,
      instance_id: instance_ocid,
      device: "/dev/oracleoci/oraclevde"
    )
  end
end
