# frozen_string_literal: true

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
