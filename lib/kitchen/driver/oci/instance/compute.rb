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
        # Setter methods that populate the details of OCI::Core::Models::LaunchInstanceDetails.
        #
        # @author Justin Steele <justin.steele@oracle.com>
        module ComputeLaunchDetails
          # Assigns the display_name and create_vnic_details to the launch_details.
          # * display_name is either the literal display_name provided in the kitchen config or a randomly generated one.
          # * create_vnic_details is a populated instance of OCI::Core::Models::CreateVnicDetails.
          def hostname_display_name
            display_name = config[:display_name] || hostname
            launch_details.display_name = display_name
            launch_details.create_vnic_details = create_vnic_details(display_name)
          end

          # Adds the preemptible_instance_config property tot he launch_details by creating a new instance of OCI::Core::Models::PreemptibleInstanceConfigDetails.
          def preemptible_instance_config
            return unless config[:preemptible_instance]

            launch_details.preemptible_instance_config = OCI::Core::Models::PreemptibleInstanceConfigDetails.new(
              preemption_action:
                OCI::Core::Models::TerminatePreemptionAction.new(
                  type: "TERMINATE", preserve_boot_volume: true
                )
            )
          end

          # Adds the shape_config property to the launch_details by creating a new instance of OCI::Core::Models::LaunchInstanceShapeConfigDetails.
          def shape_config
            return if config[:shape_config].empty?

            launch_details.shape_config = OCI::Core::Models::LaunchInstanceShapeConfigDetails.new(
              ocpus: config[:shape_config][:ocpus],
              memory_in_gbs: config[:shape_config][:memory_in_gbs],
              baseline_ocpu_utilization: config[:shape_config][:baseline_ocpu_utilization] || "BASELINE_1_1"
            )
          end

          # Adds the capacity_reservation_id property to the launch_details if an ocid is provided.
          def capacity_reservation
            launch_details.capacity_reservation_id = config[:capacity_reservation_id]
          end

          # Adds the agent_config property to the launch_details.
          def agent_config
            launch_details.agent_config = OCI::Core::Models::LaunchInstanceAgentConfigDetails.new(
              are_all_plugins_disabled: config[:all_plugins_disabled],
              is_management_disabled: config[:management_disabled],
              is_monitoring_disabled: config[:monitoring_disabled]
            )
          end

          # Adds the source_details property to the launch_details for an instance that is being created from an image.
          def instance_source_via_image
            return if config[:boot_volume_id]

            launch_details.source_details = OCI::Core::Models::InstanceSourceViaImageDetails.new(
              sourceType: "image",
              imageId: image_id,
              bootVolumeSizeInGBs: config[:boot_volume_size_in_gbs]
            )
          end

          # Adds the instance options property to the launch details.
          def instance_options
            config[:instance_options].merge!(are_legacy_imds_endpoints_disabled: true) unless config[:instance_options].key?(:are_legacy_imds_endpoints_disabled)

            launch_details.instance_options = OCI::Core::Models::InstanceOptions.new(config[:instance_options])
          end

          # Adds the source_details property to the launch_details for an instance that is being created from a boot volume.
          def instance_source_via_boot_volume
            return unless config[:boot_volume_id]

            launch_details.source_details = OCI::Core::Models::InstanceSourceViaBootVolumeDetails.new(
              boot_volume_id: clone_boot_volume,
              sourceType: "bootVolume"
            )
          end

          # Adds the metadata property to the launch_details.
          def instance_metadata
            launch_details.metadata = metadata
          end
        end
      end
    end
  end
end
