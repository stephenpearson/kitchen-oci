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
          # Launches an instance.
          #
          # @param state [Hash] (see Kitchen::StateFile)
          # @param inst [Class] the specific class of instance being launched.
          def launch(state, inst)
            state_details = inst.launch
            state.merge!(state_details)
            instance.transport.connection(state).wait_until_ready
          end

          # Executes the post script on the instance.
          #
          # @param state [Hash] (see Kitchen::StateFile)
          def process_post_script(state)
            return if config[:post_create_script].nil?

            info("Running post create script")
            script = config[:post_create_script]
            instance.transport.connection(state).execute(script)
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
