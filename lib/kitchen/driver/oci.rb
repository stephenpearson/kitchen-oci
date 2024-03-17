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
require 'openssl'
require 'uri'
require 'zlib'

module Kitchen
  module Driver
    # Oracle OCI driver for Kitchen.
    #
    # @author Stephen Pearson <stephen.pearson@oracle.com>
    class Oci < Kitchen::Driver::Base
      require_relative 'oci_version'
      require_relative 'oci/instance'
      require_relative 'oci/blockstorage'

      plugin_version Kitchen::Driver::OCI_VERSION

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
      default_config :instance_type, 'compute'
      default_config :image_id
      default_config :hostname_prefix do |hnp|
        hnp.instance.name
      end
      default_keypath = File.expand_path(File.join(%w[~ .ssh id_rsa.pub]))
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

      # compute only configs
      default_config :setup_winrm, false
      default_config :winrm_user, 'opc'
      default_config :winrm_password, nil
      default_config :preemptible_instance, false
      default_config :boot_volume_size_in_gbs, nil
      default_config :use_private_ip, false
      default_config :volumes, {}

      # dbaas configs
      default_config :dbaas, {}

      validations[:instance_type] = lambda do |_attr, val, _driver|
        validation_error('instance_type must be either compute or dbaas') unless ['compute', 'dbaas'].include?(val.downcase)
      end

      validations[:nsg_ids] = lambda do |_attr, val, _driver|
        validation_error('config value for `nsg_ids` cannot be longer than 5 items') if val.length > 5
      end

      validations[:volumes] = lambda do |_attr, val, _driver|
        val.each do |vol_attr, _vol_value|
          unless ['iscsi', 'paravirtual', nil].include?(vol_attr[:type])
            validation_error("#{vol_attr[:type]} is not a valid volume type for #{vol_attr[:name]}")
          end
        end
      end

      def self.validation_error(message)
        warn message
        exit!
      end

      def create(state)
        return if state[:server_id]

        validate_config!
        inst = instance_class(instance_type).new(config, state)

        state_details = inst.launch_instance
        state.merge!(state_details)

        instance.transport.connection(state).wait_until_ready

        unless config[:volumes].empty?
          bls = Blockstorage.new(config, state)
          state_details = bls.create_and_attach
          state.merge!(state_details)
        end

        return unless config[:post_create_script]

        info('Running post create script')
        script = config[:post_create_script]
        instance.transport.connection(state).execute(script)
      end

      def destroy(state)
        return unless state[:server_id]

        instance.transport.connection(state).close

        if state[:volumes]
          bls = Blockstorage.new(config, state)
          bls.detatch_and_delete
        end

        inst = instance_class(instance_type).new(config, state)
        inst.terminate_instance
      end

      private

      INSTANCE_MODELS = {
        compute: 'Compute',
        dbaas: 'Dbaas'
      }.freeze

      def instance_class(type)
        require_relative "oci/models/#{type}"
        Oci::Models.const_get(INSTANCE_MODELS[type])
      end

      def instance_type
        config[:instance_type].downcase.to_sym
      end
    end
  end
end
