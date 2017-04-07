# -*- encoding: utf-8 -*-
#
# Author:: Stephen Pearson (<stevieweavie@gmail.com>)
#
# Copyright (C) 2017, Stephen Pearson
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

require 'kitchen'
require 'oraclebmc'

module Kitchen
  module Driver
    # Obmc driver for Kitchen.
    #
    # @author Stephen Pearson <stevieweavie@gmail.com>
    class Oraclebmc < Kitchen::Driver::Base
      default_config :availability_domain, nil
      default_config :compartment_id, nil
      default_config :image_id, nil
      default_config :shape, nil
      default_config :subnet_id, nil
      default_config :ssh_keypath, File.expand_path('~/.ssh/id_rsa.pub')
      default_config :post_create_script, nil

      def create(state)
        return if state[:server_id]

        pubkey = File.readlines(config[:ssh_keypath]).first.chomp

        comp_api = OracleBMC::Core::ComputeClient.new
        request = OracleBMC::Core::Models::LaunchInstanceDetails.new
        request.availability_domain = config[:availability_domain]
        request.compartment_id = config[:compartment_id]
        randstr = 6.times.map { ('a'..'z').to_a.sample }.join
        hostname = "#{instance.name}-#{randstr}"
        request.display_name = hostname
        request.image_id = config[:image_id]
        request.shape = config[:shape]
        request.subnet_id = config[:subnet_id]
        request.metadata = {'ssh_authorized_keys' => pubkey}

        response = comp_api.launch_instance(request)
        instance_id = response.data.id
        response = comp_api.get_instance(instance_id).wait_until(
            :lifecycle_state,
            OracleBMC::Core::Models::Instance::LIFECYCLE_STATE_RUNNING)

        net_api = OracleBMC::Core::VirtualNetworkClient.new
        data = comp_api.get_instance(instance_id)
        vnics = comp_api.list_vnic_attachments(config[:compartment_id],
            instance_id: instance_id)
        vnic_id = vnics.data.first.vnic_id
        public_ip = net_api.get_vnic(vnic_id).data.public_ip

        state[:server_id] = instance_id
        state[:hostname] = public_ip

        instance.transport.connection(state).wait_until_ready

        if config[:post_create_script]
          info("Running post create script")
          instance.transport.connection(state).execute(
              config[:post_create_script])
        end
      end

      def destroy(state)
        return unless state[:server_id]

        instance.transport.connection(state).close

        comp_api = OracleBMC::Core::ComputeClient.new
        comp_api.terminate_instance(state[:server_id])

        state.delete(:server_id)
        state.delete(:hostname)
      end
    end
  end
end
