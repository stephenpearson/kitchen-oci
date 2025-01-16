# frozen_string_literal: true

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
