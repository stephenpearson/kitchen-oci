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
        # Actions that can be performed on an instance.
        #
        # @author Justin Steele <justin.steele@oracle.com>
        module Actions
          # Coersces config values to standardized formats.
          #
          # @param instance [Kitchen::Instance]
          def finalize_config!(instance)
            super
            %i{instance_type ssh_keytype}.each do |k|
              config[k] = config[k].downcase
            end
          end

          # Launches an instance.
          #
          # @param state [Hash] (see Kitchen::StateFile)
          # @param inst [Class] the specific class of instance being launched.
          def launch(state, inst)
            state_details = inst.launch
            state.merge!(state_details)
            instance.transport.connection(state).wait_until_ready
            instance_options(state, inst)
            are_legacy_imds_endpoints_disbled?(state, inst)
          end

          # Executes the post script on the instance.
          #
          # @param state [Hash] (see Kitchen::StateFile)
          def execute_post_create_script(state)
            return if config[:post_create_script].nil?

            if config[:post_create_script].is_a?(String)
              execute_post_create_string(state)
            elsif config[:post_create_script].is_a?(Array)
              execute_post_create_file(state)
            end
          end

          # Executes the post create script from a String.
          #
          # @param state [Hash] (see Kitchen::StateFile)
          def execute_post_create_string(state)
            info("Running post create script")
            script = config[:post_create_script]
            instance.transport.connection(state).execute(script)
          end

          # Reads the specified file and executes as a post create script.
          #
          # @param state [Hash] (see Kitchen::StateFile)
          def execute_post_create_file(state)
            config[:post_create_script].each do |script|
              info("Running post create script #{File.basename(script)}")
              script = File.read script
              instance.transport.connection(state).execute(script)
            end
          end

          # Applies instance options.
          #
          # @param state [Hash] (see Kitchen::StateFile)
          # @param inst [Class] the specific class of instance being rebooted.
          def instance_options(state, inst)
            return unless instance_options?

            inst.logger.info("Applying the following instance options:")
            config[:instance_options].each { |o, v| inst.logger.info("- #{o}: #{v}") }
            inst.api.compute.update_instance(state[:server_id], OCI::Core::Models::UpdateInstanceDetails.new(instance_options: OCI::Core::Models::InstanceOptions.new(config[:instance_options])))
          end

          # Attempts to disable IMDSv1 even if not explicitly specified in the config. This is in line with current security guidance from OCI.
          # Acts as a guard for setting instance options.
          def instance_options?
            return false unless config[:instance_type] == "compute"

            config[:instance_options].merge!(are_legacy_imds_endpoints_disabled: true) unless config[:instance_options].key?(:are_legacy_imds_endpoints_disabled)
            # Basically tell me if there's more stuff in there than `are_legacy_imds_endpoints_disabled: false`. If so, then proceed to setting it.
            config[:instance_options].reject { |o, v| o == :are_legacy_imds_endpoints_disabled && !v }.any?
          end

          # Checks if legacy metadata is disabled.
          def are_legacy_imds_endpoints_disbled?(state, inst)
            return unless config[:instance_type] == "compute"

            imds = inst.api.compute.get_instance(state[:server_id]).data.instance_options.are_legacy_imds_endpoints_disabled
            inst.logger.warn("Legacy IMDSv1 endpoint is enabled.") unless imds
          end

          # Reboots an instance.
          #
          # @param state [Hash] (see Kitchen::StateFile)
          # @param inst [Class] the specific class of instance being rebooted.
          def reboot(state, inst)
            return unless config[:post_create_reboot]

            instance.transport.connection(state).close
            inst.reboot
            instance.transport.connection(state).wait_until_ready
          end

          # Terminates an instance.
          #
          # @param state [Hash] (see Kitchen::StateFile)
          # @param inst [Class] the specific class of instance being launched.
          def terminate(state, inst)
            instance.transport.connection(state).close
            inst.terminate
            if state[:ssh_key]
              FileUtils.rm_f(state[:ssh_key])
              FileUtils.rm_f("#{state[:ssh_key]}.pub")
            end
          end
        end
      end
    end
  end
end
