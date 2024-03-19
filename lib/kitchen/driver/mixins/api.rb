# frozen_string_literal: true

#
# Author:: Justin Steele (<justin.steele@oracle.com>)
#
# Copyright:: (C) 2024, Stephen Pearson
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
      # Api mixin that defines the various API classes used to interact with OCI
      module Api
        def generic_api(klass)
          params = {}
          params[:proxy_settings] = api_proxy if api_proxy
          params[:signer] = if config[:user_instance_principals]
                              OCI::Auth::Signers::InstancePrincipalsSecurityTokenSigner.new
                            elsif config[:use_token_auth]
                              token_signer
                            end
          params[:config] = oci_config unless config[:use_instance_principals]
          klass.new(**params.compact)
        end

        def comp_api
          generic_api(OCI::Core::ComputeClient)
        end

        def net_api
          generic_api(OCI::Core::VirtualNetworkClient)
        end

        def dbaas_api
          generic_api(OCI::Database::DatabaseClient)
        end

        def ident_api
          generic_api(OCI::Identity::IdentityClient)
        end

        def blockstorage_api
          generic_api(OCI::Core::BlockstorageClient)
        end

        def token_signer
          pkey_content = oci_config.key_content || File.read(oci_config.key_file).strip
          pkey = OpenSSL::PKey::RSA.new(pkey_content, oci_config.pass_phrase)

          token = File.read(oci_config.security_token_file).strip
          OCI::Auth::Signers::SecurityTokenSigner.new(token, pkey)
        end

        def proxy_config
          if config[:proxy_url]
            URI.parse(config[:proxy_url])
          else
            URI.parse("http://example.com").find_proxy
          end
        end

        def api_proxy
          prx = proxy_config
          return unless prx

          if prx.user
            OCI::ApiClientProxySettings.new(prx.host, prx.port, prx.user,
                                            prx.password)
          else
            OCI::ApiClientProxySettings.new(prx.host, prx.port)
          end
        end
      end
    end
  end
end
