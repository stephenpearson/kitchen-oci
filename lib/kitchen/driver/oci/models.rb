# frozen_string_literal: true

#
# Author:: Stephen Pearson (<stephen.pearson@oracle.com>)
#
# Copyright (C) 2019, Stephen Pearson
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
        require_relative 'instance'
        require_relative 'blockstorage'

        INSTANCE_MODELS = {
          compute: 'Compute',
          dbaas: 'Dbaas'
        }.freeze

        ATTACHMENT_TYPES = {
          iscsi: 'Iscsi',
          paravirtual: 'Paravirtual'
        }.freeze

        def instance_class(type)
          Oci::Models.const_get(INSTANCE_MODELS[type])
        end

        def volume_class(type, config, state)
          Oci::Models.const_get(ATTACHMENT_TYPES[volume_attachment_type(type)]).new(config, state)
        end

        def instance_type
          config[:instance_type].downcase.to_sym
        end

        def volume_attachment_type(type)
          if type.nil?
            :paravirtual
          else
            type.downcase.to_sym
          end
        end
      end
    end
  end
end
