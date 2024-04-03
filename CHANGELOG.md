# kitchen-oci CHANGELOG

# 1.18.0
- feat: select image ocid for compute by display name with special sauce to select latest

# 1.17.0
- refactor: dry out instance classes and models
- chore: remove some excess code from refactor
- docs: add comments to instance methods

# 1.16.2
- fix: bug fix for post_create_script method call

# 1.16.1
- fix: remove `require_ruby_version` from gemspec for backward compatibility

# 1.16.0
- refactor: split up main class into smaller modules
- feat: add nsg_ids as property of database system
- feat: add input validations for nsg_ids, volumes, and instance_type
- fix: lookup compartment_id by name now works for tenancies with more than 99 compartments
- fix: local environment proxy setting no longer causes nil class error from URI [#24](https://github.com/stephenpearson/kitchen-oci/issues/24)
- fix: add default value for hostname_prefix
- fix: add default value for nsg_ids
- lint: lint code per chefstyle standards
- test: add spec for windows

# 1.15.1
- fix: bug fixes for volume attachments

# 1.15.0
- feat: add optional parameter `custom_metadata`

# 1.14.0
- feat: add optional parameter `defined_tags`

# 1.13.0
- feat: add Network Security Group support
- feat: add support for attaching multiple volumes

## 1.12.3
- feat: add support for specifying compartment by name

## 1.12.1
- Refactor `oci_config` method to account for `warning: Using the last argument as keyword parameters is deprecated` deprecation warning
- Set dependency on oci gem to 2.15.0

## 1.12.0
- Added support for Flex and Preemptible instances
- Set dependency on oci gem to 2.14.0
- Further reduction of characters known to cause winrm password issues

## 1.11.2
- Set dependency on oci gem to 2.10.0

## 1.11.1
- Removed characters from password string known to break winrm

## 1.11.0
- Added support for user_data raw string

## 1.10.1 Issue 22
- Added safeguard for cluster_name length restriction in DBaaS.

## 1.10.0 DBaaS support
- Added support for DBaaS.
  - instance_type is new optional parameter (compute or dbaas)

## 1.9.0 Use instance principals
- Added support for `use_instance_principals`

## 1.8.0 Freeform tags
- Added optional parameter `freeform_tags`

## 1.6.0 WinRM password option
- Added option to set winrm password, instead of randomly generating one

## 1.5.0 Windows support

- Added cloud-init support.
- Added support for Windows targets.
  - Can inject powershell script to set a random password and enable WinRM
