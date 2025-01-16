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
      # models definitions
      module Models
        require_relative "instance"
        require_relative "blockstorage"

        def instance_class(config, state, oci, api, action)
          Oci::Models.const_get(config[:instance_type].capitalize).new(config, state, oci, api, action)
        end

        def volume_class(type, config, state, oci, api)
          Oci::Models.const_get(volume_attachment_type(type)).new(config, state, oci, api)
        end

        private

        def volume_attachment_type(type)
          if type.nil?
            "Paravirtual"
          else
            type.capitalize
          end
        end
      end
    end
  end
end
