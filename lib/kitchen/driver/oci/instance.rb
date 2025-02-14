# frozen_string_literal: true

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
    class Oci
      # Base class for instance models.
      #
      # @author Justin Steele <justin.steele@oracle.com>
      class Instance < Oci # rubocop:disable Metrics/ClassLength
        require_relative "api"
        require_relative "config"
        require_relative "models/compute"
        require_relative "models/dbaas"
        require_relative "instance/common"

        include CommonLaunchDetails

        def initialize(opts = {})
          super()
          @config = opts[:config]
          @state = opts[:state]
          @oci = opts[:oci]
          @api = opts[:api]
          @logger = opts[:logger]
        end

        # The config provided by the driver.
        #
        # @return [Kitchen::LazyHash]
        attr_accessor :config

        # The definition of the state of the instance from the statefile.
        #
        # @return [Hash]
        attr_accessor :state

        # The config object that contains properties of the authentication to OCI.
        #
        # @return [Kitchen::Driver::Oci::Config]
        attr_accessor :oci

        # The API object that contains each of the authenticated clients for interfacing with OCI.
        #
        # @return [Kitchen::Driver::Oci::Api]
        attr_accessor :api

        # The instance of Kitchen::Logger in use by the active Kitchen::Instance.
        #
        # @return [Kitchen::Logger]
        attr_accessor :logger

        # Adds the instance info into the state.
        #
        # @param state [Hash] The state from kitchen.
        # @return [Hash]
        def final_state(state, instance_id)
          state.store(:server_id, instance_id)
          state.store(:hostname, instance_ip(instance_id))
          state
        end

        private

        # Calls all of the setter methods for the self.
        #
        # @return [OCI::Core::Models::LaunchInstanceDetails, OCI::Database::Models::LaunchDbSystemDetails] the fully populated launch details for the specific instance type.
        def launch_instance_details
          launch_methods = []
          self.class.ancestors.reverse.select { |m| m.is_a?(Module) && m.name.start_with?("#{self.class.superclass}::") }.each do |klass|
            launch_methods << klass.instance_methods(false)
          end
          launch_methods.flatten.each { |m| send(m) }
          launch_details
        end

        # Checks if public IP addresses are allowed in the specified subnet.
        #
        # @return [Boolean]
        def public_ip_allowed?
          subnet = api.network.get_subnet(config[:subnet_id]).data
          !subnet.prohibit_public_ip_on_vnic
        end

        # Returns the location of the public ssh key.
        #
        # @return [String]
        def public_key_file
          if config[:ssh_keygen]
            "#{config[:kitchen_root]}/.kitchen/.ssh/#{config[:instance_name]}_rsa.pub"
          else
            config[:ssh_keypath]
          end
        end

        # Returns the name of the private key file.
        #
        # @return [String]
        def private_key_file
          public_key_file.gsub(".pub", "")
        end

        # Generates an RSA key pair to be used to SSH to the instance and updates the state with the full path to the private key.
        def gen_key_pair
          FileUtils.mkdir_p("#{config[:kitchen_root]}/.kitchen/.ssh")
          rsa_key = OpenSSL::PKey::RSA.new(4096)
          write_private_key(rsa_key)
          write_public_key(rsa_key)
          state.store(:ssh_key, private_key_file)
        end

        # Writes the private key.
        #
        # @param rsa_key [OpenSSL::PKey::RSA] the generated RSA key.
        def write_private_key(rsa_key)
          File.open(private_key_file, "wb") { |k| k.write(rsa_key.to_pem) }
          File.chmod(0600, private_key_file)
        end

        # Writes the encoded private key as a public key.
        #
        # @param rsa_key [OpenSSL::PKey::RSA] the generated RSA key.
        def write_public_key(rsa_key)
          File.open(public_key_file, "wb") { |k| k.write("ssh-rsa #{encode_private_key(rsa_key)} #{config[:instance_name]}") }
          File.chmod(0600, public_key_file)
        end

        # Encodes the private key.
        #
        # @param rsa_key [OpenSSL::PKey::RSA] the generated RSA key.
        def encode_private_key(rsa_key)
          prefix = "#{[7].pack("N")}ssh-rsa"
          exponent = rsa_key.e.to_s(0)
          modulus = rsa_key.n.to_s(0)
          ["#{prefix}#{exponent}#{modulus}"].pack("m0")
        end

        # Generates a random password.
        #
        # @param special_chars [Array] an array of special characters to include in the random password.
        # @return [String]
        def random_password(special_chars)
          (Array.new(5) { special_chars.sample } +
            Array.new(5) { ("a".."z").to_a.sample } +
            Array.new(5) { ("A".."Z").to_a.sample } +
            Array.new(5) { ("0".."9").to_a.sample }).shuffle.join
        end

        # Generates a random string of letters.
        #
        # @param length [Integer] how many characters to randomize.
        # @return [String]
        def random_string(length)
          Array.new(length) { ("a".."z").to_a.sample }.join
        end

        # Generates a random string of numbers.
        #
        # @param length [Integer] how many numbers to randomize.
        # @return [String]
        def random_number(length)
          Array.new(length) { ("0".."9").to_a.sample }.join
        end

        # Parses freeform tags to be added to the instance by the setter method.
        #
        # @return [Hash]
        def process_freeform_tags
          tags = %w{run_list policyfile}
          fft = config[:freeform_tags]
          tags.each do |tag|
            unless fft[tag.to_sym].nil? || fft[tag.to_sym].empty?
              fft[tag] =
                prov[tag.to_sym].join(",")
            end
          end
          fft[:kitchen] = true
          fft
        end

        # Encodes specified user_data to be added to cloud-init.
        #
        # @return [Base64]
        def user_data
          case config[:user_data]
          when Array
            Base64.encode64(multi_part_user_data.close.string).delete("\n")
          when String
            Base64.encode64(config[:user_data]).delete("\n")
          end
        end

        # GZips processed user_data prior to being encoded to allow for multi-part inclusions.
        #
        # @return [Zlib::GzipWriter]
        def multi_part_user_data
          boundary = "MIMEBOUNDARY_#{random_string(20)}"
          msg = ["Content-Type: multipart/mixed; boundary=\"#{boundary}\"",
                 "MIME-Version: 1.0", ""]
          msg += mime_parts(boundary)
          txt = "#{msg.join("\n")}\n"
          gzip = Zlib::GzipWriter.new(StringIO.new)
          gzip << txt
        end

        # Joins all of the bits provided by each itema in user_data with the provided boundary and content headers.
        #
        # @param boundary [String]
        # @return [Array]
        def mime_parts(boundary)
          msg = []
          config[:user_data].each do |m|
            msg << "--#{boundary}"
            msg << "Content-Disposition: attachment; filename=\"#{m[:filename]}\""
            msg << "Content-Transfer-Encoding: 7bit"
            msg << "Content-Type: text/#{m[:type]}" << "Mime-Version: 1.0" << ""
            msg << read_part(m) << ""
          end
          msg << "--#{boundary}--"
          msg
        end

        # Reads either the specified file or the text provided inline.
        #
        # @param part [Hash] the current item in the user_data hash being processed.
        # @return [Array]
        def read_part(part)
          if part[:path]
            content = File.read part[:path]
          elsif part[:inline]
            content = part[:inline]
          else
            raise "Invalid user data"
          end
          content.split("\n")
        end
      end
    end
  end
end
