# frozen_string_literal: true

#
# Author:: Stephen Pearson (<stephen.pearson@oracle.com>)
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
require 'uri'

module Kitchen
  module Driver
    # Oracle OCI driver for Kitchen.
    #
    # @author Stephen Pearson <stephen.pearson@oracle.com>
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
      default_config :proxy_url, nil

      def create(state) # rubocop:disable Metrics/AbcSize
        return if state[:server_id]

        instance_id = launch_instance
        state[:server_id] = instance_id
        state[:hostname] = instance_ip(instance_id)

        instance.transport.connection(state).wait_until_ready

        return unless config[:post_create_script]

        info('Running post create script')
        script = config[:post_create_script]
        instance.transport.connection(state).execute(script)
      end

      def destroy(state)
        return unless state[:server_id]

        instance.transport.connection(state).close
        comp_api.terminate_instance(state[:server_id])

        state.delete(:server_id)
        state.delete(:hostname)
      end

      private

      def oci_config
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

      def proxy_config
        if config[:proxy_url]
          URI.parse(config[:proxy_url])
        else
          URI.parse('http://').find_proxy
        end
      end

      def api_proxy
        prx = proxy_config
        return nil unless prx
        if prx.user
          OCI::ApiClientProxySettings.new(prx.host, prx.port, prx.user,
                                          prx.password)
        else
          OCI::ApiClientProxySettings.new(prx.host, prx.port)
        end
      end

      def generic_api(klass)
        api_prx = api_proxy
        if api_prx
          klass.new(config: oci_config, proxy_settings: api_prx)
        else
          klass.new(config: oci_config)
        end
      end

      def comp_api
        generic_api(OCI::Core::ComputeClient)
      end

      def net_api
        generic_api(OCI::Core::VirtualNetworkClient)
      end

      def launch_instance
        request = compute_instance_request

        response = comp_api.launch_instance(request)
        instance_id = response.data.id
        comp_api.get_instance(instance_id).wait_until(
          :lifecycle_state,
          OCI::Core::Models::Instance::LIFECYCLE_STATE_RUNNING
        )
        instance_id
      end

      def vnic_attachments(instance_id)
        att = comp_api.list_vnic_attachments(
          config[:compartment_id],
          instance_id: instance_id
        ).data
        raise 'Could not find any VNIC attachments' unless att.any?
        att
      end

      def vnics(instance_id)
        vnic_attachments(instance_id).map do |att|
          net_api.get_vnic(att.vnic_id).data
        end
      end

      def instance_ip(instance_id)
        vnic = vnics(instance_id).select(&:is_primary).first
        if public_ip_allowed?
          config[:use_private_ip] ? vnic.private_ip : vnic.public_ip
        else
          vnic.private_ip
        end
      end

      def pubkey
        File.readlines(config[:ssh_keypath]).first.chomp
      end

      def instance_source_details
        OCI::Core::Models::InstanceSourceViaImageDetails.new(
          sourceType: 'image',
          imageId: config[:image_id]
        )
      end

      def public_ip_allowed?
        subnet = net_api.get_subnet(config[:subnet_id]).data
        !subnet.prohibit_public_ip_on_vnic
      end

      def create_vnic_details(name)
        OCI::Core::Models::CreateVnicDetails.new(
          assign_public_ip: public_ip_allowed?,
          display_name: name,
          hostname_label: name,
          subnetId: config[:subnet_id]
        )
      end

      def compute_instance_request # rubocop:disable Metrics/AbcSize
        hostname = random_hostname(instance.name)
        request = OCI::Core::Models::LaunchInstanceDetails.new
        request.availability_domain = config[:availability_domain]
        request.compartment_id = config[:compartment_id]
        request.display_name = hostname
        request.source_details = instance_source_details
        request.shape = config[:shape]
        request.create_vnic_details = create_vnic_details(hostname)
        request.metadata = { 'ssh_authorized_keys' => pubkey }
        request
      end

      def random_hostname(prefix)
        randstr = Array.new(6) { ('a'..'z').to_a.sample }.join
        "#{prefix}-#{randstr}"
      end
    end
  end
end
