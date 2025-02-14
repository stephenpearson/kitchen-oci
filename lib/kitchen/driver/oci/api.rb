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
    class Oci
      # Defines the various API classes used to interact with OCI.
      #
      # @author Justin Steele <justin.steele@oracle.com>
      class Api
        def initialize(oci_config, config)
          @oci_config = oci_config
          @config = config
        end

        # The config used to authenticate to OCI.
        #
        # @return [OCI::Config]
        attr_reader :oci_config

        # The config provided by the driver.
        #
        # @return [Kitchen::LazyHash]
        attr_reader :config

        # Creates a Compute API client.
        #
        # @return [OCI::Core::ComputeClient]
        def compute
          generic_api(OCI::Core::ComputeClient)
        end

        # Creates a Network API client.
        #
        # @return [OCI::Core::VirtualNetworkClient]
        def network
          generic_api(OCI::Core::VirtualNetworkClient)
        end

        # Creates a Database API client.
        #
        # @return [OCI::Core::DatabaseClient]
        def dbaas
          generic_api(OCI::Database::DatabaseClient)
        end

        # Creates an Identity API client.
        #
        # @return [OCI::Core::IdentityClient]
        def identity
          generic_api(OCI::Identity::IdentityClient)
        end

        # Creates a Blockstorage API client.
        #
        # @return [OCI::Core::BlockstorageClient]
        def blockstorage
          generic_api(OCI::Core::BlockstorageClient)
        end

        private

        # Instantiates the specified client class.
        #
        # @param klass [Class] The client class to instantiate.
        # @return [Object] an instance of <b>klass</b>.
        def generic_api(klass)
          params = {}
          params[:proxy_settings] = api_proxy if api_proxy
          params[:signer] = signer
          params[:config] = oci_config unless config[:use_instance_principals]
          # this is to accommodate old versions of ruby that do not have a compact method on a Hash
          params.reject! { |_, v| v.nil? }
          klass.new(**params)
        end

        # Determines the signing method if one is specified.
        #
        # @return [OCI::Auth::Signers::InstancePrincipalsSecurityTokenSigner, OCI::Auth::Signers::SecurityTokenSigner] an instance of the specified token signer.
        def signer
          if config[:use_instance_principals]
            OCI::Auth::Signers::InstancePrincipalsSecurityTokenSigner.new
          elsif config[:use_token_auth]
            token_signer
          end
        end

        # Creates the token signer with a provided key.
        #
        # @return [OCI::Auth::Signers::SecurityTokenSigner]
        def token_signer
          pkey_content = oci_config.key_content || File.read(oci_config.key_file).strip
          pkey = OpenSSL::PKey::RSA.new(pkey_content, oci_config.pass_phrase)

          token = File.read(oci_config.security_token_file).strip
          OCI::Auth::Signers::SecurityTokenSigner.new(token, pkey)
        end

        # Parse any specified proxy from either the kitchen config or the environment.
        #
        # @return [URI] a parsed proxy host.
        def proxy_config
          if config[:proxy_url]
            URI.parse(config[:proxy_url])
          else
            URI.parse("http://example.com").find_proxy
          end
        end

        # Create the proxy settings for the OCI API.
        #
        # @return [OCI::ApiClientProxySettings]
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
