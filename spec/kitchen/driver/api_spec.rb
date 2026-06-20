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

  shared_examples "a client with token auth" do |clients|
    clients.each do |method, klass|
      it "creates #{method} client" do
        expect(klass).to receive(:new).with(signer: signer, config: oci_config)
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

  context "clients using token auth" do
    before do
      OCI::Config.class_eval { attr_accessor :security_token_file } unless OCI::Config.instance_methods.include?(:security_token_file)
      allow(File).to receive(:read).with(key_file).and_return(key_content)
      allow(File).to receive(:read).with(security_token_file).and_return(token)
      allow(File).to receive(:exist?).with(security_token_file).and_return(true)
      allow(OpenSSL::PKey::RSA).to receive(:new).with(key_content, nil).and_return(private_key)
      allow(OCI::Auth::Signers::SecurityTokenSigner).to receive(:new).with(token, private_key).and_return(signer)
    end
    let(:key_file) { "/fake/.oci/key.pem" }
    let(:key_content) { "fake-private-key" }
    let(:security_token_file) { "/fake/.oci/token" }
    let(:token) { "fake-security-token" }
    let(:private_key) { instance_double(OpenSSL::PKey::RSA) }
    let(:signer) { instance_double(OCI::Auth::Signers::SecurityTokenSigner) }
    let(:oci_config) do
      OCI::Config.new.tap do |c|
        c.key_file = key_file
        c.security_token_file = security_token_file
      end
    end

    context "when use_token_auth is set explicitly" do
      let(:driver_config) { { use_token_auth: true } }
      it_behaves_like "a client with token auth", clients
    end

    context "when a security_token_file is detected in the profile (RPST session)" do
      let(:driver_config) { {} }
      it_behaves_like "a client with token auth", clients
    end
  end
end
