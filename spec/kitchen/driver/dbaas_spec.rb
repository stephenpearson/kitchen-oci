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

describe Kitchen::Driver::Oci::Models::Dbaas do
  include_context "dbaas"

  describe "#create" do
    include_context "create"

    let(:state) { {} }
    it "creates a dbaas instance" do
      expect(dbaas_client).to receive(:launch_db_system).with(db_system_launch_details)
      expect(dbaas_client).to receive(:get_db_system).with(db_system_ocid).and_return(dbaas_response)
      expect(dbaas_client).to receive(:list_db_nodes).with(compartment_ocid, db_system_id: db_system_ocid).and_return(db_nodes_response)
      expect(dbaas_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.dbaas("available"), max_interval_seconds: 900, max_wait_seconds: 21_600)
      expect(transport).to receive_message_chain("connection.wait_until_ready")
      driver.create(state)
      expect(state).to match(
        {
          hostname: private_ip,
          server_id: db_system_ocid,
        }
      )
    end
  end

  describe "#destroy" do
    include_context "destroy"
    include_context "dbaas"

    let(:state) { { server_id: db_system_ocid } }
    it "destroys a dbaas instance" do
      expect(dbaas_client).to receive(:terminate_db_system).with(db_system_ocid)
      expect(dbaas_response).to receive(:wait_until).with(:lifecycle_state, Lifecycle.dbaas("terminating"), max_interval_seconds: 900, max_wait_seconds: 21_600)
      expect(transport).to receive_message_chain("connection.close")
      driver.destroy(state)
    end
  end
end
