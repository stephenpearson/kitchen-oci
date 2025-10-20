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
      # Execute the defined config validations
      #
      # @param message [String] the message to be output to explain the validation.
      # @param driver [Kitchen::Driver] the instance of the driver.
      # @raise [UserError]
      def self.validation_error(message, driver)
        raise UserError, "#{driver.class}<#{driver.instance.name}>#config#{message}"
      end

      # Coerces config values to standardized formats.
      #
      # @param instance [Kitchen::Instance]
      def finalize_config!(instance)
        super
        %i{instance_type ssh_keytype}.each do |k|
          config[k] = config[k].downcase
        end
      end

      validations[:instance_type] = lambda do |attr, val, driver|
        validation_error("[:#{attr}] #{val} is not a valid instance_type. must be either compute or dbaas.", driver) unless %w{compute dbaas}.include?(val.downcase)
      end

      validations[:nsg_ids] = lambda do |attr, val, driver|
        unless val.nil?
          validation_error("[:#{attr}] list cannot be longer than 5 items", driver) if val.length > 5
        end
      end

      validations[:volumes] = lambda do |attr, val, driver|
        val.each do |vol_attr|
          unless ["iscsi", "paravirtual", nil].include?(vol_attr[:type])
            validation_error("[:#{attr}][:type] #{vol_attr[:type]} is not a valid volume type for #{vol_attr[:name]}", driver)
          end
        end
      end

      validations[:ssh_keytype] = lambda do |attr, val, driver|
        validation_error("[:#{attr}] #{val} is not a supported ssh key type.", driver) unless %w{rsa ed25519}.include?(val.downcase)
      end
    end
  end
end
