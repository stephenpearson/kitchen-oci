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

require "spec_helper"

describe Kitchen::Driver::Oci::Api do
  include_context "api"

  subject { Kitchen::Driver::Oci::Api.new(oci_config, driver_config) }

  shared_examples "a client without a proxy" do |clients|
    clients.each do |method, klass|
      it "creates #{method} client" do
        expect(klass).to receive(:new).with(config: oci_config)
        subject.send(method)
      end
    end
  end

  shared_examples "a client with a proxy" do |clients|
    clients.each do |method, klass|
      it "creates #{method} client" do
        expect(klass).to receive(:new).with(config: oci_config, proxy_settings: proxy_settings)
        subject.send(method)
      end
    end
  end

  shared_examples "a client with instance principals" do |clients|
    clients.each do |method, klass|
      it "creates #{method} client" do
        expect(klass).to receive(:new).with(signer: signer)
        subject.send(method)
      end
    end
  end

  clients = {
    compute: OCI::Core::ComputeClient,
    network: OCI::Core::VirtualNetworkClient,
    dbaas: OCI::Database::DatabaseClient,
    identity: OCI::Identity::IdentityClient,
    blockstorage: OCI::Core::BlockstorageClient,
  }

  context "clients without proxy" do
    it_behaves_like "a client without a proxy", clients
  end

  context "clients with proxy by reading the environment" do
    include_context "proxy"
    it_behaves_like "a client with a proxy", clients
  end

  context "clients using instance principals" do
    before do
      allow(OCI::Auth::Signers::InstancePrincipalsSecurityTokenSigner).to receive(:new).and_return(signer)
    end
    let(:signer) { class_double(OCI::Auth::Signers::InstancePrincipalsSecurityTokenSigner) }
    let(:driver_config) { { use_instance_principals: true } }
    it_behaves_like "a client with instance principals", clients
  end
end
