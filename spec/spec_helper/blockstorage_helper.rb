# frozen_string_literal: true

RSpec.shared_context "blockstorage", :blockstorage do
  let(:boot_volume_ocid) { "ocid1.bootvolume.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345" }
  let(:clone_boot_volume_ocid) { "ocid1.bootvolume.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz67890" }
  let(:boot_volume_display_name) { "kitchen-foo (Boot Volume)" }
  let(:boot_volume_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::BootVolume.new(id: boot_volume_ocid,
                                                                  display_name: boot_volume_display_name))
  end
  let(:clone_boot_volume_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::BootVolume.new(id: clone_boot_volume_ocid,
                                                                  lifecycle_state: Lifecycle.volume("available")))
  end
  let(:boot_volume_details) do
    OCI::Core::Models::CreateBootVolumeDetails.new(
      source_details: OCI::Core::Models::BootVolumeSourceFromBootVolumeDetails.new(
        id: boot_volume_ocid
      ),
      display_name: "#{boot_volume_display_name} (Clone)",
      compartment_id: compartment_ocid,
      defined_tags: {}
    )
  end
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
    allow(blockstorage_client).to receive(:get_boot_volume).with(boot_volume_ocid).and_return(boot_volume_response)
    allow(blockstorage_client).to receive(:get_boot_volume).with(clone_boot_volume_ocid).and_return(clone_boot_volume_response)
    allow(blockstorage_client).to receive(:create_boot_volume).with(boot_volume_details).and_return(clone_boot_volume_response)
    allow(blockstorage_client).to receive(:get_volume).with(iscsi_volume_ocid).and_return(iscsi_blockstorage_response)
    allow(blockstorage_client).to receive(:get_volume).with(pv_volume_ocid).and_return(pv_blockstorage_response)
    allow(blockstorage_client).to receive(:create_volume).with(pv_volume_details).and_return(pv_blockstorage_response)
    allow(clone_boot_volume_response).to receive(:wait_until).with(:lifecycle_state,
                                                                   Lifecycle.volume("available")).and_return(boot_volume_response)
    allow(iscsi_blockstorage_response).to receive(:wait_until).with(:lifecycle_state,
                                                                    Lifecycle.volume("available")).and_return(iscsi_blockstorage_response)
    allow(iscsi_attachment_response).to receive(:wait_until).with(:lifecycle_state,
                                                                  Lifecycle.volume_attachment("attached")).and_return(iscsi_attachment_response)
    allow(pv_attachment_response).to receive(:wait_until).with(:lifecycle_state,
                                                               Lifecycle.volume_attachment("attached")).and_return(pv_attachment_response)
    allow(pv_blockstorage_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.volume("available")).and_return(pv_blockstorage_response)
  end
end
