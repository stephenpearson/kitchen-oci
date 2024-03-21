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
    class Oci
      # generic class for instance models
      class Instance < Oci
        require_relative "api"
        require_relative "config"
        require_relative "models/compute"
        require_relative "models/dbaas"

        attr_accessor :config, :state, :oci, :api

        def initialize(config, state, oci, api, action)
          super()
          @config = config
          @state = state
          @oci = oci
          @api = api
        end

        def compartment_id
          launch_details.compartment_id = oci.compartment
        end

        def availability_domain
          launch_details.availability_domain = config[:availability_domain]
        end

        def defined_tags
          launch_details.defined_tags = config[:defined_tags]
        end

        def shape
          launch_details.shape = config[:shape]
        end

        def freeform_tags
          launch_details.freeform_tags = process_freeform_tags
        end

        def final_state(state, instance_id)
          state.store(:server_id, instance_id)
          state.store(:hostname, instance_ip(instance_id))
          state
        end

        private

        def public_ip_allowed?
          subnet = api.network.get_subnet(config[:subnet_id]).data
          !subnet.prohibit_public_ip_on_vnic
        end

        def random_password(special_chars)
          (Array.new(5) { special_chars.sample } +
            Array.new(5) { ("a".."z").to_a.sample } +
            Array.new(5) { ("A".."Z").to_a.sample } +
            Array.new(5) { ("0".."9").to_a.sample }).shuffle.join
        end

        def random_string(length)
          Array.new(length) { ("a".."z").to_a.sample }.join
        end

        def random_number(length)
          Array.new(length) { ("0".."9").to_a.sample }.join
        end

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

        def user_data
          case config[:user_data]
          when Array
            Base64.encode64(multi_part_user_data.close.string).delete("\n")
          when String
            Base64.encode64(config[:user_data]).delete("\n")
          end
        end

        def multi_part_user_data
          boundary = "MIMEBOUNDARY_#{random_string(20)}"
          msg = ["Content-Type: multipart/mixed; boundary=\"#{boundary}\"",
                 "MIME-Version: 1.0", ""]
          msg += mime_parts(boundary)
          txt = "#{msg.join("\n")}\n"
          gzip = Zlib::GzipWriter.new(StringIO.new)
          gzip << txt
        end

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
