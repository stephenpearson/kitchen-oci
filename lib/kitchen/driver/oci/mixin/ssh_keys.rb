# frozen_string_literal: true

#
# Author:: Justin Steele (<justin.steele@oracle.com>)
#
# Copyright (C) 2025, Stephen Pearson
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
      module Mixin
        # SSH key generation mixins.
        #
        # @author Justin Steele <justin.steele@oracle.com>
        module SshKeys
          # Read in the public ssh key.
          #
          # @return [String]
          def read_public_key
            if config[:ssh_keygen]
              logger.info("Generating public/private #{config[:ssh_keytype]} key pair")
              generate_keys
            end
            File.readlines(public_key_file).first.chomp
          end

          # The location of the private ssh key.
          #
          # @return [String]
          def private_key_file
            public_key_file.gsub(".pub", "")
          end

          # The location of the public ssh key.
          #
          # @return [String]
          def public_key_file
            if config[:ssh_keygen]
              "#{config[:kitchen_root]}/.kitchen/.ssh/#{config[:instance_name]}_#{config[:ssh_keytype]}.pub"
            else
              config[:ssh_keypath]
            end
          end

          # Algorithm used when encoding the private and public keys.
          #
          # @return [String]
          def algorithm
            "ssh-#{config[:ssh_keytype]}"
          end

          # Generates the public/private key pair in the format specified in the config.
          def generate_keys
            FileUtils.mkdir_p("#{config[:kitchen_root]}/.kitchen/.ssh")
            extend SshKeys.const_get(config[:ssh_keytype].upcase)
            generate_key_pair
          end

          # Mixins required to generate a RSA key pair.
          #
          # @author Justin Steele <justin.steele@oracle.com>
          module RSA
            # Generates an RSA key pair to be used to SSH to the instance and updates the state with the full path to the private key.
            def generate_key_pair
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
              public_key = ["#{[7].pack("N")}#{algorithm}#{rsa_key.e.to_s(0)}#{rsa_key.n.to_s(0)}"].pack("m0")
              File.open(public_key_file, "wb") { |k| k.write("#{algorithm} #{public_key} #{config[:instance_name]}") }
              File.chmod(0600, public_key_file)
            end
          end

          # Mixins required to generate a ED25519 key pair.
          #
          # @author Justin Steele <justin.steele@oracle.com>
          module ED25519
            require "ed25519"
            require "securerandom" unless defined?(SecureRandom)

            # Generates an ED25519 key pair to be used to SSH to the instance and updates the state with the full path to the private key.
            def generate_key_pair
              signing_key = Ed25519::SigningKey.generate
              private_seed = signing_key.to_bytes
              public_key = signing_key.verify_key.to_bytes
              write_private_key(public_key, private_seed)
              write_public_key(public_key)
              state.store(:ssh_key, private_key_file)
            end

            # Packs a string as SSH “string” (4-byte len + bytes).
            #
            # @param str [String] the portion of the key being packed.
            # @return [String]
            def pack_string(str)
              [str.bytesize].pack("N") + str
            end

            # Writes the encoded private key.
            #
            # @param public_key [String] the byte representation of the <code>Ed25519::VerifyKey</code>.
            # @param private_seed [String] the byte representation of the <code>Ed25519::SigningKey</code>.
            def write_private_key(public_key, private_seed)
              private_key = encode_private_key(public_key, private_seed)
              File.open(private_key_file, "w") { |f| f.write(private_key) }
              File.chmod(0600, private_key_file)
            end

            # Writes the encoded public key.
            #
            # @param public_key [String] the byte representation of the <code>Ed25519::VerifyKey</code>.
            def write_public_key(public_key)
              pub_key = encode_public_key(public_key)
              File.open(public_key_file, "w") { |f| f.write(pub_key) }
              File.chmod(0600, public_key_file)
            end

            # Encodes the private key.
            #
            # @param public_key [String] the byte representation of the <code>Ed25519::VerifyKey</code>.
            # @param private_seed [String] the byte representation of the <code>Ed25519::SigningKey</code>.
            # @return [String]
            def encode_private_key(public_key, private_seed)
              buf  = header(public_key)
              priv = private_section(public_key, private_seed)
              padlen = (-priv.bytesize) & 7
              priv << (1..padlen).to_a.pack("C*")
              buf << pack_string(priv)
              b64 = Base64.strict_encode64(buf).scan(/.{1,70}/).join("\n")
              "-----BEGIN OPENSSH PRIVATE KEY-----\n#{b64}\n-----END OPENSSH PRIVATE KEY-----\n"
            end

            # "openssh-key-v1" header: magic, cipher/kdf, nkeys, and the public key blob(s).
            #
            # @param public_key [String] the byte representation of the <code>Ed25519::VerifyKey</code>.
            # @return [String]
            def header(public_key)
              [
                "openssh-key-v1\0",
                pack_string("none"),  # ciphername
                pack_string("none"),  # kdfname
                pack_string(""),      # kdfoptions
                [1].pack("N"),        # nkeys
                pack_string(pub_blob(public_key)),
              ].join
            end

            # Correct private section: checkints, key fields, comment, padding
            #
            # @param public_key [String] the byte representation of the <code>Ed25519::VerifyKey</code>.
            # @param private_seed [String] the byte representation of the <code>Ed25519::SigningKey</code>.
            # @return [String]
            def private_section(public_key, private_seed)
              checkint = SecureRandom.random_number(2**32)
              [
                [checkint, checkint].pack("N*"),
                pack_string(algorithm),
                pack_string(public_key),
                pack_string(private_seed + public_key),
                pack_string(config[:instance_name] || ""),
              ].join
            end

            # Encodes the public key.
            #
            # @param public_key [String] the byte representation of the <code>Ed25519::VerifyKey</code>.
            # @return [String]
            def encode_public_key(public_key)
              blob = [algorithm.bytesize].pack("N") + algorithm + [public_key.bytesize].pack("N") + public_key
              [algorithm, Base64.strict_encode64(blob), config[:instance_name]].compact.join(" ")
            end

            # SSH public key blob: string keytype + string key (32 bytes).
            #
            # @param public_key [String] the byte representation of the <code>Ed25519::VerifyKey</code>.
            # @return [String]
            def pub_blob(public_key)
              pack_string(algorithm) + pack_string(public_key)
            end
          end
        end
      end
    end
  end
end
