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

module Kitchen
  module Driver
    module Mixins
      # OciConfig mixin that defines the oci config that will be used for the API calls
      module OciConfig
        def oci_config
          # OCI::Config is missing this
          OCI::Config.class_eval { attr_accessor :security_token_file } if config[:use_token_auth]
          conf = config_loader(config_file_location: config[:oci_config_file], profile_name: config[:oci_profile_name])
          config[:oci_config].each do |key, value|
            conf.send("#{key}=", value) unless value.nil? || value.empty?
          end
          conf
        end

        def tenancy
          if config[:use_instance_principals]
            sign = OCI::Auth::Signers::InstancePrincipalsSecurityTokenSigner.new
            sign.instance_variable_get '@tenancy_id'
          else
            oci_config.tenancy
          end
        end

        def compartment_id
          return config[:compartment_id] if config[:compartment_id]

          raise 'must specify either compartment_id or compartment_name' unless config[:compartment_name]

          compartment_ocid = compartment_id_by_name(config[:compartment_name])
          return compartment_ocid unless compartment_ocid.nil?

          raise 'compartment not found'
        end

        private

        def config_loader(opts = {})
          OCI::ConfigFileLoader.load_config(**opts.compact)
        rescue OCI::ConfigFileLoader::Errors::ConfigFileNotFoundError
          OCI::Config.new
        end

        def compartment_id_by_name(name)
          all_compartments(oci_config.tenancy).select { |c| c.name == name }[0]&.id
        end

        def all_compartments(tenancy, compartments = [], page = nil)
          current_compartments = ident_api.list_compartments(tenancy, page: page)
          next_page = current_compartments.next_page
          compartments << current_compartments.data
          all_compartments(tenancy, compartments, next_page) unless next_page.nil?
          compartments.flatten
        end
      end
    end
  end
end
