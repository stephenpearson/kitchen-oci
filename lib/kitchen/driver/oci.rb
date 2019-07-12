# frozen_string_literal: true

#
# Author:: Stephen Pearson (<stephen.pearson@oracle.com>)
#
# Copyright (C) 2019, Stephen Pearson
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

# rubocop:disable Metrics/AbcSize

# This require fixes bug in ChefDK 4.0.60-1 on Linux.
require 'forwardable'

require 'base64'
require 'erb'
require 'kitchen'
require 'oci'
require 'uri'
require 'zlib'

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
      default_config :hostname_prefix, nil
      default_keypath = File.expand_path(File.join(%w[~ .ssh id_rsa.pub]))
      default_config :ssh_keypath, default_keypath
      default_config :post_create_script, nil
      default_config :proxy_url, nil
      default_config :user_data, []
      default_config :freeform_tags, {}
      default_config :setup_winrm, false
      default_config :winrm_user, 'opc'
      default_config :winrm_password, nil

      def process_freeform_tags(freeform_tags)
        prov = instance.provisioner.instance_variable_get(:@config)
        tags = %w[run_list policyfile]
        tags.each do |tag|
          unless prov[tag.to_sym].nil? || prov[tag.to_sym].empty?
            freeform_tags[tag] = prov[tag.to_sym].join(',')
          end
        end
        freeform_tags[:kitchen] = true
        freeform_tags
      end

      def process_windows_options(state)
        state[:username] = config[:winrm_user] if config[:setup_winrm]
        if config[:setup_winrm] == true &&
           config[:password].nil? &&
           state[:password].nil?
          state[:password] = config[:winrm_password] || random_password
        end
        state
      end

      def create(state)
        return if state[:server_id]

        state = process_windows_options(state)

        instance_id = launch_instance(state)
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

      def launch_instance(state)
        request = compute_instance_request(state)

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

      def winrm_ps1(state)
        filename = File.join(__dir__, %w[.. .. .. tpl setup_winrm.ps1.erb])
        tpl = ERB.new(File.read(filename))
        tpl.result(binding)
      end

      def read_part(part)
        if part[:path]
          content = File.read part[:path]
        elsif part[:inline]
          content = part[:inline]
        else
          raise 'Invalid user data'
        end
        content.split("\n")
      end

      def mime_parts(boundary)
        msg = []
        config[:user_data].each do |m|
          msg << "--#{boundary}"
          msg << "Content-Disposition: attachment; filename=\"#{m[:filename]}\""
          msg << 'Content-Transfer-Encoding: 7bit'
          msg << "Content-Type: text/#{m[:type]}" << 'Mime-Version: 1.0' << ''
          msg << read_part(m) << ''
        end
        msg << "--#{boundary}--"
        msg
      end

      def user_data
        boundary = "MIMEBOUNDARY_#{random_string(20)}"
        msg = ["Content-Type: multipart/mixed; boundary=\"#{boundary}\"",
               'MIME-Version: 1.0', '']
        msg += mime_parts(boundary)
        txt = msg.join("\n") + "\n"
        gzip = Zlib::GzipWriter.new(StringIO.new)
        gzip << txt
        Base64.encode64(gzip.close.string).delete("\n")
      end

      def inject_powershell(state)
        data = winrm_ps1(state)
        config[:user_data] ||= []
        config[:user_data] << {
          type: 'x-shellscript',
          inline: data,
          filename: 'setup_winrm.ps1'
        }
      end

      def generate_hostname
        prefix = config[:hostname_prefix]
        [prefix, random_hostname(instance.name)].compact.join('-')
      end

      def base_oci_launch_details
        OCI::Core::Models::LaunchInstanceDetails.new.tap do |l|
          hostname = generate_hostname
          l.availability_domain = config[:availability_domain]
          l.compartment_id = config[:compartment_id]
          l.display_name = hostname
          l.source_details = instance_source_details
          l.shape = config[:shape]
          l.create_vnic_details = create_vnic_details(hostname)
          l.freeform_tags = process_freeform_tags(config[:freeform_tags])
        end
      end

      def compute_instance_request(state)
        request = base_oci_launch_details

        inject_powershell(state) if config[:setup_winrm] == true

        metadata = {}
        metadata.store('ssh_authorized_keys', pubkey)
        data = user_data
        metadata.store('user_data', data) if config[:user_data].any?
        request.metadata = metadata
        request
      end

      def random_hostname(prefix)
        "#{prefix}-#{random_string(6)}"
      end

      def random_password
        (Array.new(5) { %w[! " # & ( ) * + , - . /].sample } +
         Array.new(5) { ('a'..'z').to_a.sample } +
         Array.new(5) { ('A'..'Z').to_a.sample } +
         Array.new(5) { ('0'..'9').to_a.sample }).shuffle.join
      end

      def random_string(length)
        Array.new(length) { ('a'..'z').to_a.sample }.join
      end
    end
  end
end

# rubocop:enable Metrics/AbcSize
