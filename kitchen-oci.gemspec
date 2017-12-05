lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/oci_version'

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-oci'
  spec.version       = Kitchen::Driver::OCI_VERSION
  spec.authors       = ['Stephen Pearson']
  spec.email         = ['stevieweavie@gmail.com']
  spec.description   = 'A Test Kitchen Driver for Oracle OCI'
  spec.summary       = spec.description
  spec.homepage      = ''
  spec.license       = 'Apache-2.0'

  # rubocop:disable SpecialGlobalVars
  spec.files         = `git ls-files`.split($/)
  # rubocop:enable SpecialGlobalVars
  spec.executables   = []
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'oci', '~> 2.0'
  spec.add_dependency 'test-kitchen'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'cane'
  spec.add_development_dependency 'countloc'
  spec.add_development_dependency 'rake'
end
