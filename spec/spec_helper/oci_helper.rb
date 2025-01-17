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
