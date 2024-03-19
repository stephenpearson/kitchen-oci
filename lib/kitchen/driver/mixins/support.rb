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
    module Mixins
      # Supporting mixins for common tasks
      module Support
        def random_password(special_chars)
          (Array.new(5) { special_chars.sample } +
            Array.new(5) { ("a".."z").to_a.sample } +
            Array.new(5) { ("A".."Z").to_a.sample } +
            Array.new(5) { ("0".."9").to_a.sample }).shuffle.join
        end

        def random_string(length)
          Array.new(length) { ("a".."z").to_a.sample }.join
        end

        def random_number(length)
          Array.new(length) { ("0".."9").to_a.sample }.join
        end
      end
    end
  end
end
