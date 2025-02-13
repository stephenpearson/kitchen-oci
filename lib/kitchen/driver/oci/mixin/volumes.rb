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
      module Mixin
        # mixin for working with volumes and attachments
        module Volumes
          def create_and_attach_volumes(config, state, oci, api)
            return if config[:volumes].empty?

            volume_state = process_volumes(config, state, oci, api)
            state.merge!(volume_state)
          end

          def detatch_and_delete_volumes(state, oci, api)
            return unless state[:volumes]

            bls = Blockstorage.new(config: config, state: state, oci: oci, api: api, action: :destroy, logger: instance.logger)
            state[:volume_attachments].each { |att| bls.detatch_volume(att) }
            state[:volumes].each { |vol| bls.delete_volume(vol) }
          end

          def process_volumes(config, state, oci, api)
            volume_state = { volumes: [], volume_attachments: [] }
            config[:volumes].each do |volume|
              vol = volume_class(volume[:type], config, state, oci, api)
              volume_details, vol_state = create_volume(vol, volume)
              attach_state = vol.attach_volume(volume_details, state[:server_id], volume)
              volume_state[:volumes] << vol_state
              volume_state[:volume_attachments] << attach_state
            end
            volume_state
          end

          def create_volume(vol, volume)
            if volume.key?(:volume_id)
              vol.create_clone_volume(volume)
            else
              vol.create_volume(volume)
            end
          end
        end
      end
    end
  end
end
