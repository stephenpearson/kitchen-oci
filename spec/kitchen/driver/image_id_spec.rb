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

describe Kitchen::Driver::Oci::Models::Compute do
  include_context "compute"
  include_context "create"

  shared_examples "image_name provided" do |images|
    images.each do |display_name, ocid|
      context display_name do
        subject { Kitchen::Driver::Oci::Models::Compute.new(config: driver_config, state: state, oci: oci_config, api: api, action: :create) }
        let(:state) { {} }
        let(:api) { Kitchen::Driver::Oci::Api.new(oci, driver_config) }
        let(:driver_config) do
          base_driver_config.merge!({
                                      image_id: nil,
                                      image_name: display_name,
                                    })
        end

        before do
          allow(compute_client).to receive(:list_images).and_return(list_images_response)
          allow(list_images_response).to receive(:next_page).and_return(nil)
        end

        it "selects the right image ocid for #{display_name}" do
          selected_image_id = subject.send(:image_id)
          expect(selected_image_id).to eq(ocid)
        end
      end
    end
  end

  images = {
    "Oracle-Linux-9.3" => "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz123456",
    "Oracle-Linux-9.3-aarch64" => "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz147852",
    "Oracle-Linux-8.9" => "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz456321",
    "Oracle-Linux-8.9-aarch64" => "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz789654",
  }

  context "#image_id" do
    it_behaves_like "image_name provided", images
  end
end

describe Kitchen::Driver::Oci::Models::Compute do
  include_context "compute"
  include_context "create"

  context "append aarch64 for ARM shapes" do
    subject { Kitchen::Driver::Oci::Models::Compute.new(config: driver_config, state: state, oci: oci_config, api: api, action: :create) }
    let(:state) { {} }
    let(:api) { Kitchen::Driver::Oci::Api.new(oci, driver_config) }
    let(:driver_config) do
      base_driver_config.merge!(
        {
          image_id: nil,
          image_name: "Oracle-Linux-9.3", # test with an image name that does not include aarch64
          shape: "VM.Standard.A1.Flex", # Arm shape
        }
      )
    end

    before do
      allow(compute_client).to receive(:list_images).and_return(list_images_response)
      allow(list_images_response).to receive(:next_page).and_return(nil)
    end

    it "adjusts the image name to include -aarch64" do
      expected_image_name = "Oracle-Linux-9.3-aarch64"
      expect(subject.send(:image_name_conversion)).to eq(expected_image_name)
    end

    it "selects the right image ocid for Oracle-Linux-9.3" do
      expected_image_ocid = "ocid1.image.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz147852"
      selected_image_id = subject.send(:image_id)
      expect(selected_image_id).to eq(expected_image_ocid)
    end
  end
end
