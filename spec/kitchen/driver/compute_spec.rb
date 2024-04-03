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

  describe "#create" do
    include_context "create"

    let(:state) { {} }
    let(:driver_config) { base_driver_config }

    context "standard compute (Linux)" do
      it "creates a compute instance with no volumes" do
        expect(compute_client).to receive(:launch_instance).with(launch_instance_request)
        expect(compute_client).to receive(:get_instance).with(instance_ocid)
        expect(compute_client).to receive(:list_vnic_attachments).with(compartment_ocid, instance_id: instance_ocid)
        expect(compute_response).to receive(:wait_until).with(:lifecycle_state,
                                                             Lifecycle.compute("running")).and_return(compute_response)
        expect(transport).to receive_message_chain("connection.wait_until_ready")
        driver.create(state)
        expect(state).to match(
          {
            hostname: private_ip,
            server_id: instance_ocid,
          }
        )
      end
    end

    context "standard compute (Linux) with post_create_script" do
      let(:driver_config) do
        base_driver_config.merge!({
                                    post_create_script: "echo 'Hello World!'",
                                  })
      end
      before do
        allow(transport).to receive_message_chain("connection.wait_until_ready")
      end
      it "executes the post_create_script" do
        expect(transport).to receive_message_chain("connection.execute").with("echo 'Hello World!'")
        driver.create(state)
      end
    end

    context "standard compute (Windows) with custom metadata" do
      # kitchen.yml driver config section
      let(:driver_config) do
        base_driver_config.merge!({
                                    setup_winrm: true,
                                    winrm_password: "f4k3p@55w0rd",
                                    custom_metadata: {
                                      "hostclass" => "foo",
                                    },
                                  })
      end
      let(:instance_metadata) do
        {
          "ssh_authorized_keys" => ssh_pub_key,
          "user_data" => "FaKeUsErDaTa",
          "hostclass" => "foo",
        }
      end
      let(:winrm_user) { "opc" }
      let(:winrm_password) { "f4k3p@55w0rd" }

      it "creates a windows compute instance with no volumes" do
        expect(compute_client).to receive(:launch_instance).with(launch_instance_request)
        expect(compute_client).to receive(:get_instance).with(instance_ocid)
        expect(compute_client).to receive(:list_vnic_attachments).with(compartment_ocid, instance_id: instance_ocid)
        expect(transport).to receive_message_chain("connection.wait_until_ready")
        driver.create(state)
        expect(state).to match(
          {
            hostname: private_ip,
            server_id: instance_ocid,
            password: winrm_password,
            username: winrm_user,
          }
        )
      end
    end

    context "standard compute with nsg" do
      # kitchen.yml driver config section
      let(:driver_config) do
        base_driver_config.merge!({

                                    nsg_ids: [
                                      "ocid1.networksecuritygroup.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz12345",
                                      "ocid1.networksecuritygroup.oc1.fake.aaaaaaaaaabcdefghijklmnopqrstuvwxyz67890",
                                    ],
                                  })
      end

      it "creates a compute instance with nsg_ids specified" do
        expect(compute_client).to receive(:launch_instance).with(launch_instance_request)
        driver.create(state)
        expect(state).to match(
          {
            hostname: private_ip,
            server_id: instance_ocid,
          }
        )
      end
    end

    context "compute with volumes" do
      context "iscsi volume" do
        # kitchen.yml driver config section
        let(:driver_config) do
          base_driver_config.merge!({
                                      volumes: [
                                        {
                                          name: iscsi_display_name,
                                          size_in_gbs: 10,
                                          type: "iscsi",
                                        },
                                      ],
                                    })
        end

        it "creates a compute instance with iscsi attached volume" do
          expect(blockstorage_client).to receive(:create_volume).with(iscsi_volume_details).and_return(iscsi_blockstorage_response)
          expect(blockstorage_client).to receive(:get_volume).with(iscsi_volume_ocid).and_return(iscsi_blockstorage_response)
          expect(compute_client).to receive(:attach_volume).with(iscsi_attachment).and_return(iscsi_attachment_response)
          expect(compute_client).to receive(:get_volume_attachment).with(iscsi_attachment_ocid).and_return(iscsi_attachment_response)
          expect(iscsi_blockstorage_response).to receive(:wait_until).with(:lifecycle_state,
                                                                           Lifecycle.volume("available")).and_return(iscsi_blockstorage_response)
          expect(iscsi_attachment_response).to receive(:wait_until).with(:lifecycle_state,
                                                                         Lifecycle.volume_attachment("attached")).and_return(iscsi_attachment_response)
          driver.create(state)
          expect(state).to match(
            {
              hostname: private_ip,
              server_id: instance_ocid,
              volume_attachments: [
                {
                  id: iscsi_attachment_ocid,
                  display_name: iscsi_attachment_display_name,
                  iqn: iqn,
                  iqn_ipv4: ipv4,
                  port: port,
                },
              ],
              volumes: [
                {
                  display_name: driver_config[:volumes][0][:name],
                  id: iscsi_volume_ocid,
                },
              ],
            }
          )
        end
      end

      context "paravirtual volume" do
        # kitchen.yml driver config section
        let(:driver_config) do
          base_driver_config.merge!({
                                      volumes: [
                                        {
                                          name: pv_display_name,
                                          size_in_gbs: 10,
                                        },
                                      ],
                                    })
        end

        it "creates a compute instance with paravirtual attached volume by default" do
          expect(blockstorage_client).to receive(:create_volume).with(pv_volume_details).and_return(pv_blockstorage_response)
          expect(blockstorage_client).to receive(:get_volume).with(pv_volume_ocid).and_return(pv_blockstorage_response)
          expect(compute_client).to receive(:attach_volume).with(pv_attachment).and_return(pv_attachment_response)
          expect(compute_client).to receive(:get_volume_attachment).with(pv_attachment_ocid).and_return(pv_attachment_response)
          expect(pv_blockstorage_response).to receive(:wait_until).with(:lifecycle_state,
                                                                    Lifecycle.volume("available")).and_return(pv_blockstorage_response)
          expect(pv_attachment_response).to receive(:wait_until).with(:lifecycle_state,
                                                                  Lifecycle.volume_attachment("attached")).and_return(pv_attachment_response)
          driver.create(state)
          expect(state).to match(
            {
              hostname: private_ip,
              server_id: instance_ocid,
              volume_attachments: [
                {
                  id: pv_attachment_ocid,
                  display_name: pv_attachment_display_name,
                },
              ],
              volumes: [
                {
                  display_name: pv_display_name,
                  id: pv_volume_ocid,
                },
              ],
            }
          )
        end
      end
    end
  end

  describe "#destroy" do
    include_context "destroy"

    context "standard compute" do
      let(:state) { { server_id: instance_ocid } }

      it "destroys a compute instance with no volumes" do
        expect(compute_client).to receive(:terminate_instance).with(instance_ocid)
        expect(transport).to receive_message_chain("connection.close")
        driver.destroy(state)
      end
    end

    context "compute with volumes" do
      let(:state) do
        {
          server_id: instance_ocid,
          volumes: [
            {
              id: pv_volume_ocid,
              display_name: pv_display_name,
            },
          ],
          volume_attachments: [
            {
              id: pv_attachment_ocid,
              display_name: pv_attachment_display_name,
            },
          ],
        }
      end
      it "destroys a compute instance with volumes attached" do
        expect(compute_client).to receive(:detach_volume).with(pv_attachment_ocid)
        expect(blockstorage_client).to receive(:delete_volume).with(pv_volume_ocid)
        expect(compute_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.compute("terminating"))
        driver.destroy(state)
      end
    end
  end
end
