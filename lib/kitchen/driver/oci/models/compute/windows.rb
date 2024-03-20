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
      module Models
        class Compute
          # windows specific properties
          module Windows
            def process_windows_options
              return unless windows_state?

              state.store(:username, config[:winrm_user])
              state.store(:password, config[:winrm_password] || random_password(%w{@ - ( ) .}))
            end

            def windows_state?
              config[:setup_winrm] && config[:password].nil? && state[:password].nil?
            end

            def winrm_ps1
              filename = File.join(__dir__, %w{.. .. .. .. .. .. tpl setup_winrm.ps1.erb})
              tpl = ERB.new(File.read(filename))
              tpl.result(binding)
            end

            def inject_powershell
              return unless config[:setup_winrm]

              data = winrm_ps1
              config[:user_data] ||= []
              config[:user_data] << {
                type: "x-shellscript",
                inline: data,
                filename: "setup_winrm.ps1",
              }
            end
          end
        end
      end
    end
  end
end
