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
        # setter methods that populate the details of OCI::Core::Models::LaunchInstanceDetails
        module ComputeLaunchDetails
          def hostname_display_name
            display_name = hostname
            launch_details.display_name = display_name
            launch_details.create_vnic_details = create_vnic_details(display_name)
          end

          def preemptible_instance_config
            return unless config[:preemptible_instance]

            launch_details.preemptible_instance_config = OCI::Core::Models::PreemptibleInstanceConfigDetails.new(
              preemption_action:
                OCI::Core::Models::TerminatePreemptionAction.new(
                  type: "TERMINATE", preserve_boot_volume: true
                )
            )
          end

          def shape_config
            return if config[:shape_config].empty?

            launch_details.shape_config = OCI::Core::Models::LaunchInstanceShapeConfigDetails.new(
              ocpus: config[:shape_config][:ocpus],
              memory_in_gbs: config[:shape_config][:memory_in_gbs],
              baseline_ocpu_utilization: config[:shape_config][:baseline_ocpu_utilization] || "BASELINE_1_1"
            )
          end

          def agent_config
            launch_details.agent_config = OCI::Core::Models::LaunchInstanceAgentConfigDetails.new(
              are_all_plugins_disabled: config[:all_plugins_disabled],
              is_management_disabled: config[:management_disabled],
              is_monitoring_disabled: config[:monitoring_disabled]
            )
          end

          def instance_source_details
            launch_details.source_details = OCI::Core::Models::InstanceSourceViaImageDetails.new(
              sourceType: "image",
              imageId: image_id,
              bootVolumeSizeInGBs: config[:boot_volume_size_in_gbs]
            )
          end

          def instance_metadata
            launch_details.metadata = metadata
          end
        end
      end
    end
  end
end
