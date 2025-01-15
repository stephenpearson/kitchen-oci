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
    allow_any_instance_of(Kitchen::Driver::Oci::Models::Compute).to receive(:info)
    allow_any_instance_of(Kitchen::Driver::Oci::Config).to receive(:compartment).and_return(compartment_ocid)
    # stubbed for now. the encoding is making spec difficult right now.  plan to add specific units for the user data methods.
    allow_any_instance_of(Kitchen::Driver::Oci::Instance).to receive(:user_data).and_return("FaKeUsErDaTa")
  end
end
