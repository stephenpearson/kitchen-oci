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

require_relative "api"

module Kitchen
  module Driver
    class Oci
      # Config class that defines the oci config that will be used for the API calls
      class Config
        def initialize(driver_config)
          setup_driver_config(driver_config)
          @config = oci_config
        end

        #
        # The config used to authenticate to OCI
        #
        # @return [OCI::Config]
        #
        attr_reader :config

        def oci_config
          # OCI::Config is missing this
          OCI::Config.class_eval { attr_accessor :security_token_file } if @driver_config[:use_token_auth]
          conf = config_loader(config_file_location: @driver_config[:oci_config_file], profile_name: @driver_config[:oci_profile_name])
          @driver_config[:oci_config].each do |key, value|
            conf.send("#{key}=", value) unless value.nil? || value.empty?
          end
          conf
        end

        def compartment
          @compartment ||= @compartment_id
          return @compartment if @compartment

          raise "must specify either compartment_id or compartment_name" unless [@compartment_id, @compartment_name].any?

          @compartment ||= compartment_id_by_name(@compartment_name)
          raise "compartment not found" unless @compartment
        end

        private

        def setup_driver_config(config)
          @driver_config = config
          @compartment_id = config[:compartment_id]
          @compartment_name = config[:compartment_name]
        end

        def config_loader(opts = {})
          OCI::ConfigFileLoader.load_config(**opts.compact)
        rescue OCI::ConfigFileLoader::Errors::ConfigFileNotFoundError
          OCI::Config.new
        end

        def tenancy
          if @driver_config[:use_instance_principals]
            sign = OCI::Auth::Signers::InstancePrincipalsSecurityTokenSigner.new
            sign.instance_variable_get "@tenancy_id"
          else
            config.tenancy
          end
        end

        def compartment_id_by_name(name)
          api = Oci::Api.new(config, @driver_config).identity
          all_compartments(api, config.tenancy).select { |c| c.name == name }&.first&.id
        end

        def all_compartments(api, tenancy, compartments = [], page = nil)
          current_compartments = api.list_compartments(tenancy, page: page)
          next_page = current_compartments.next_page
          compartments << current_compartments.data
          all_compartments(api, tenancy, compartments, next_page) unless next_page.nil?
          compartments.flatten
        end
      end
    end
  end
end
