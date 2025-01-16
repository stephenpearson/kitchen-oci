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
