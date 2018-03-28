# frozen_string_literal: true

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
require 'oci'

module Kitchen
  module Driver
    # Oracle OCI driver for Kitchen.
    #
    # @author Stephen Pearson <stevieweavie@gmail.com>
    class Oci < Kitchen::Driver::Base # rubocop:disable Metrics/ClassLength
      required_config :compartment_id
      required_config :availability_domain
      required_config :image_id
      required_config :shape
      required_config :subnet_id

      default_config :use_private_ip, false
      default_config :oci_config_file, nil
      default_config :oci_profile_name, nil
      default_keypath = File.expand_path(File.join(%w[~ .ssh id_rsa.pub]))
      default_config :ssh_keypath, default_keypath
      default_config :post_create_script, nil

      def create(state) # rubocop:disable Metrics/AbcSize
        return if state[:server_id]

        instance_id = launch_instance(config)
        state[:server_id] = instance_id
        state[:hostname] = instance_ip(config, instance_id)

        instance.transport.connection(state).wait_until_ready

        return unless config[:post_create_script]

        info('Running post create script')
        script = config[:post_create_script]
        instance.transport.connection(state).execute(script)
      end

      def destroy(state)
        return unless state[:server_id]

        instance.transport.connection(state).close
        comp_api(config).terminate_instance(state[:server_id])

        state.delete(:server_id)
        state.delete(:hostname)
      end

      private

      def oci_config(config)
        params = [:load_config]
        opts = {}
        if config[:oci_config_file]
          opts[:config_file_location] = config[:oci_config_file]
        end
        if config[:oci_profile_name]
          opts[:profile_name] = config[:oci_profile_name]
        end
        params << opts
        OCI::ConfigFileLoader.send(*params)
      end

      def comp_api(config)
        OCI::Core::ComputeClient.new(config: oci_config(config))
      end

      def net_api(config)
        OCI::Core::VirtualNetworkClient.new(config: oci_config(config))
      end

      def launch_instance(config)
        request = compute_instance_request(config)

        response = comp_api(config).launch_instance(request)
        instance_id = response.data.id
        comp_api(config).get_instance(instance_id).wait_until(
          :lifecycle_state,
          OCI::Core::Models::Instance::LIFECYCLE_STATE_RUNNING
        )
        instance_id
      end

      def vnic_attachments(config, instance_id)
        att = comp_api(config).list_vnic_attachments(
          config[:compartment_id],
          instance_id: instance_id
        ).data
        raise 'Could not find any VNIC attachments' unless att.any?
        att
      end

      def vnics(config, instance_id)
        vnic_attachments(config, instance_id).map do |att|
          net_api(config).get_vnic(att.vnic_id).data
        end
      end

      def instance_ip(config, instance_id)
        vnic = vnics(config, instance_id).select(&:is_primary).first
        if public_ip_allowed?(config)
          config[:use_private_ip] ? vnic.private_ip : vnic.public_ip
        else
          vnic.private_ip
        end
      end

      def pubkey(config)
        File.readlines(config[:ssh_keypath]).first.chomp
      end

      def instance_source_details(config)
        OCI::Core::Models::InstanceSourceViaImageDetails.new(
          sourceType: 'image',
          imageId: config[:image_id]
        )
      end

      def public_ip_allowed?(config)
        subnet = net_api(config).get_subnet(config[:subnet_id]).data
        !subnet.prohibit_public_ip_on_vnic
      end

      def create_vnic_details(config)
        OCI::Core::Models::CreateVnicDetails.new(
          assign_public_ip: public_ip_allowed?(config),
          display_name: 'primary_nic',
          subnetId: config[:subnet_id]
        )
      end

      def compute_instance_request(config)
        request = OCI::Core::Models::LaunchInstanceDetails.new
        request.availability_domain = config[:availability_domain]
        request.compartment_id = config[:compartment_id]
        request.display_name = random_hostname(instance.name)
        request.source_details = instance_source_details(config)
        request.shape = config[:shape]
        request.create_vnic_details = create_vnic_details(config)
        request.metadata = { 'ssh_authorized_keys' => pubkey(config) }
        request
      end

      def random_hostname(prefix)
        randstr = Array.new(6) { ('a'..'z').to_a.sample }.join
        "#{prefix}-#{randstr}"
      end
    end
  end
end
