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
      # Config class that defines the oci config that will be used for the API calls.
      #
      # @author Justin Steele <justin.steele@oracle.com>
      class Config
        def initialize(driver_config)
          setup_driver_config(driver_config)
          @config = oci_config
        end

        # The config used to authenticate to OCI.
        #
        # @return [OCI::Config]
        attr_reader :config

        # Creates a new instance of OCI::Config to be used to authenticate to OCI.
        #
        # @return [OCI::Config]
        def oci_config
          # OCI::Config is missing this
          OCI::Config.class_eval { attr_accessor :security_token_file } if @driver_config[:use_token_auth]
          conf = config_loader(config_file_location: @driver_config[:oci_config_file], profile_name: @driver_config[:oci_profile_name])
          @driver_config[:oci_config].each do |key, value|
            conf.send("#{key}=", value) unless value.nil? || value.empty?
          end
          conf
        end

        # The ocid of the compartment where the Kitchen instance will be created.
        # * If <b>compartment_id</b> is specified in the kitchen.yml, that will be returned.
        # * If <b>compartment_name</b> is specified in the kitchen.yml, lookup with the Identity API to find the ocid by the compartment name.
        #
        # @return [String] the ocid of the compartment where instances will be created.
        # @raise [StandardError] if neither <b>compartment_id</b> nor <b>compartment_name</b> are specified OR if lookup by name fails to find a match.
        def compartment
          @compartment ||= @compartment_id
          return @compartment if @compartment

          raise "must specify either compartment_id or compartment_name" unless [@compartment_id, @compartment_name].any?

          @compartment ||= compartment_id_by_name(@compartment_name)
          raise "compartment not found" unless @compartment
        end

        private

        # Sets up instance variables from the driver config (parsed kitchen.yml) and compartment.
        #
        # @param config [Hash] the parsed config from the kitchen.yml.
        def setup_driver_config(config)
          @driver_config = config
          @compartment_id = config[:compartment_id]
          @compartment_name = config[:compartment_name]
        end

        # Creates a new instance of OCI::Config either by loading the config from a file or returning a new instance that will be set.
        #
        # @param opts [Hash]
        # @return [OCI::Config]
        def config_loader(opts = {})
          # this is to accommodate old versions of ruby that do not have a compact method on a Hash
          opts.reject! { |_, v| v.nil? }
          OCI::ConfigFileLoader.load_config(**opts)
        rescue OCI::ConfigFileLoader::Errors::ConfigFileNotFoundError
          OCI::Config.new
        end

        # Returns the ocid of the tenancy from either the provided ocid or from your instance principals.
        #
        # @return [String]
        def tenancy
          if @driver_config[:use_instance_principals]
            sign = OCI::Auth::Signers::InstancePrincipalsSecurityTokenSigner.new
            sign.instance_variable_get "@tenancy_id"
          else
            config.tenancy
          end
        end

        # Looks up the compartment ocid by name by recursively querying the list of compartments with the Identity API.
        #
        # @return [String] the ocid of the compartment.
        def compartment_id_by_name(name)
          api = Oci::Api.new(config, @driver_config).identity
          all_compartments(api, config.tenancy).select { |c| c.name == name }&.first&.id
        end

        # Pages through all of the compartments in the tenancy. This has to be a recursive process because the list_compartments API only returns 99 entries at a time.
        #
        # @return [Array] An array of OCI::Identity::Models::Compartment
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
