# frozen_string_literal: true

#   Copyright 2020 Stephen Pearson <stephen.pearson@oracle.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require 'bundler/gem_tasks'
require 'cane/rake_task'
require 'tailor/rake_task'

desc 'Run cane to check quality metrics'
Cane::RakeTask.new do |cane|
  cane.canefile = './.cane'
end

Tailor::RakeTask.new

desc 'Display LOC stats'
task :stats do
  puts '\n## Production Code Stats'
  sh 'countloc -r lib'
end

desc 'Run all quality tasks'
task quality: %i[cane tailor stats]

task default: %i[quality]
