# kitchen-oci CHANGELOG

# 2.0.0
- feat: set default value for `are_legacy_imds_endpoints_disabled` to `true`
  > BREAKING CHANGE: This overrides the default value to `true` in accordance with latest [OCI secuirty guidelines](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/gettingmetadata.htm)

# 1.28.0
- feat: add instance_options to compute instance type

# 1.27.0
- feat: extend `post_create_script` to accept a list of script files
- doc: add YARD tags to all methods and classes and add `metadata` to the gemspec

# 1.26.0
- feat: generate rsa key pair automatically per instance

# 1.25.0
- feat: allow `image_name` to function the same for ARM as it does for Linux

# 1.24.0
- feat: change pessimistic lock on oci gem to just `~> 2.18` 

# 1.23.0
- feat: add `capacity_reservation_id` for compute shapes

# 1.22.0
- feat: add `volume_id` to `volumes` config option to allow for cloning of block volumes
- feat: add `device` to `volumes` config option to allow for mapping block volumes on attachment

# 1.21.0
- feat: add `display_name` config value to override name randomization for compute

# 1.20.2
- fix: change default value for `nsg_ids` to `nil`

# 1.20.1
- fix: use provided `defined_tags` when creating block volume, boot volume clones, and all dbaas components

# 1.20.0
- feat: add `boot_volume_id` config option to allow for instance creation from a clone of the specified boot volume
- feat: add `db_software_image_id` config option for dbaas to allow instance creation from a database software image
- fix: add `instance_name` back to the generated hostname and display_name

# 1.19.0
- feat: add `post_create_reboot` config option

# 1.18.1
- fix: backward compatible fixes to support Ruby 2.3.0
  
# 1.18.0
- feat: select image ocid for compute by display name with special sauce to select latest
- feat: add `agent_config` property to compute launch details

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
