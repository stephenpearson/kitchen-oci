# frozen_string_literal: true

RSpec.shared_context "create", :create do
  let(:compute_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::Instance.new(id: instance_ocid,
                                                                image_id: image_ocid,
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
  let(:db_node_response) do
    OCI::Response.new(200, nil, OCI::Database::Models::DbNode.new(id: db_node_ocid, lifecycle_state: Lifecycle.dbaas("available")))
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
  let(:get_linux_image_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::Image.new(id: image_ocid, operating_system: "Oracle Linux"))
  end
  let(:get_windows_image_response) do
    OCI::Response.new(200, nil, OCI::Core::Models::Image.new(id: image_ocid, operating_system: "Windows"))
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
