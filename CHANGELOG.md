
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
