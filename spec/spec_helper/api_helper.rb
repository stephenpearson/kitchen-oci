# frozen_string_literal: true

RSpec.shared_context "api", :common do |rspec|
  let(:oci_config) { class_double(OCI::Config) }
  let(:driver_config) { {} }
end
