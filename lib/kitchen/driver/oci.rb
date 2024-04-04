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

# This require fixes bug in ChefDK 4.0.60-1 on Linux.
require "forwardable" unless defined?(Forwardable)
require "base64" unless defined?(Base64)
require "erb" unless defined?(Erb)
require "kitchen"
require "oci"
require "openssl" unless defined?(OpenSSL)
require "uri" unless defined?(URI)
require "zlib" unless defined?(Zlib)

module Kitchen
  module Driver
    # Oracle OCI driver for Kitchen.
    #
    # @author Stephen Pearson <stephen.pearson@oracle.com>
    class Oci < Kitchen::Driver::Base # rubocop:disable Metrics/ClassLength
      require_relative "oci_version"
      require_relative "oci/models"

      plugin_version Kitchen::Driver::OCI_VERSION
      kitchen_driver_api_version 1

      # required config items
      required_config :availability_domain
      required_config :shape
      required_config :subnet_id

      # common config items
      default_config :oci_config, {}
      default_config :oci_config_file, nil
      default_config :oci_profile_name, nil
      default_config :compartment_id, nil
      default_config :compartment_name, nil
      default_config :instance_type, "compute"
      default_config :image_id, nil
      default_config :image_name, nil
      default_config :hostname_prefix do |hnp|
        hnp.instance.name
      end
      default_keypath = File.expand_path(File.join(%w{~ .ssh id_rsa.pub}))
      default_config :ssh_keypath, default_keypath
      default_config :post_create_script, nil
      default_config :proxy_url, nil
      default_config :user_data, nil
      default_config :freeform_tags, {}
      default_config :defined_tags, {}
      default_config :custom_metadata, {}
      default_config :use_instance_principals, false
      default_config :use_token_auth, false
      default_config :shape_config, {}
      default_config :nsg_ids, []
      default_config :all_plugins_disabled, false
      default_config :management_disabled, false
      default_config :monitoring_disabled, false

      # compute only configs
      default_config :setup_winrm, false
      default_config :winrm_user, "opc"
      default_config :winrm_password, nil
      default_config :preemptible_instance, false
      default_config :boot_volume_size_in_gbs, nil
      default_config :use_private_ip, false
      default_config :volumes, {}

      # dbaas configs
      default_config :dbaas, {}

      validations[:instance_type] = lambda do |attr, val, driver|
        validation_error("[:#{attr}] #{val} is not a valid instance_type. must be either compute or dbaas.", driver) unless %w{compute dbaas}.include?(val.downcase)
      end

      validations[:nsg_ids] = lambda do |attr, val, driver|
        validation_error("[:#{attr}] list cannot be longer than 5 items", driver) if val.length > 5
      end

      validations[:volumes] = lambda do |attr, val, driver|
        val.each do |vol_attr|
          unless ["iscsi", "paravirtual", nil].include?(vol_attr[:type])
            validation_error("[:#{attr}][:type] #{vol_attr[:type]} is not a valid volume type for #{vol_attr[:name]}", driver)
          end
        end
      end

      def self.validation_error(message, driver)
        raise UserError, "#{driver.class}<#{driver.instance.name}>#config#{message}"
      end

      include Kitchen::Driver::Oci::Models

      def create(state)
        return if state[:server_id]

        validate_config!
        oci, api = auth(__method__)
        inst = instance_class(config, state, oci, api, __method__)
        state_details = inst.launch
        state.merge!(state_details)
        instance.transport.connection(state).wait_until_ready
        create_and_attach_volumes(config, state, oci, api)
        process_post_script(state)
      end

      def destroy(state)
        return unless state[:server_id]

        oci, api = auth(__method__)
        instance.transport.connection(state).close
        detatch_and_delete_volumes(state, oci, api) if state[:volumes]
        inst = instance_class(config, state, oci, api, __method__)
        inst.terminate
      end

      private

      def auth(action)
        oci = Oci::Config.new(config)
        api = Oci::Api.new(oci.config, config)
        oci.compartment if action == :create
        [oci, api]
      end

      def create_and_attach_volumes(config, state, oci, api)
        return if config[:volumes].empty?

        volume_state = { volumes: [], volume_attachments: [] }
        config[:volumes].each do |volume|
          vol = volume_class(volume[:type], config, state, oci, api)
          volume_details, vol_state = vol.create_volume(volume)
          attach_state = vol.attach_volume(volume_details, state[:server_id])
          volume_state[:volumes] << vol_state
          volume_state[:volume_attachments] << attach_state
        end
        state.merge!(volume_state)
      end

      def detatch_and_delete_volumes(state, oci, api)
        bls = Blockstorage.new(config, state, oci, api, :destroy)
        state[:volume_attachments].each { |att| bls.detatch_volume(att) }
        state[:volumes].each { |vol| bls.delete_volume(vol) }
      end

      def process_post_script(state)
        return if config[:post_create_script].nil?

        info("Running post create script")
        script = config[:post_create_script]
        instance.transport.connection(state).execute(script)
      end
    end
  end
end
