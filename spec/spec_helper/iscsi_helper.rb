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
