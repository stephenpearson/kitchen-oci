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
      class Instance
        # Setter methods that populate launch details common to all instance models.
        #
        # @author Justin Steele <justin.steele@oracle.com>
        module CommonLaunchDetails
          # Assigns the ocid of the compartment to the launch details.
          def compartment_id
            launch_details.compartment_id = oci.compartment
          end

          # Assigns the availability_domain to the launch details.
          def availability_domain
            launch_details.availability_domain = config[:availability_domain]
          end

          # Assigns the defined_tags to the launch details.
          def defined_tags
            launch_details.defined_tags = config[:defined_tags]
          end

          # Assigns the shape to the launch_details.
          def shape
            launch_details.shape = config[:shape]
          end

          # Assigns the freeform_tags to the launch_details.
          def freeform_tags
            launch_details.freeform_tags = process_freeform_tags
          end
        end
      end
    end
  end
end
