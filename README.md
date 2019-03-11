# Kitchen::OCI

A Test Kitchen Driver for Oracle Bare Metal Cloud

## Prerequisites

You need an ssh keypair defined for your current user.  By default the driver
expects to find the public key in ~/.ssh/id\_rsa.pub, but this can be
overridden in .kitchen.yml.

You need to create suitable configuration for OCI in ~/.oci/config and this
can be created using the CLI:
```
oci setup config
```

Ensure that you have a suitable compartment defined, an external subnet, and
security rules that allow incoming SSH and outgoing HTTP to allow Kitchen to
pull the Chef binaries.

## Building the gem

```
rake build
```

## Installing the gem

You must install the gem into whatever Ruby is used to run knife.  On a
workstation this will likely be the ChefDK environment.  To switch to
ChefDK if you haven't already:

```
eval "$(chef shell-init bash)"
```

Then install the package you built earlier:

```
gem install pkg/kitchen-oci-<VERSION>.gem
```

## Example .kitchen.yml

Adjust below template as required.  The following configuration is mandatory:

   - compartment\_id
   - availability\_domain
   - image\_id
   - shape
   - subnet\_id

Note: The availability domain should be the full AD name including the tenancy specific prefix.  For example: "AaBb:US-ASHBURN-AD-1".  Look in the OCI console to get your tenancy specific string.

These settings are optional:

   - use\_private\_ip, Whether to connect to the instance using a private IP, default is false (public ip)
   - oci\_config\_file, OCI configuration file, by default this is ~/.oci/config
   - oci\_profile\_name, OCI profile to use, default value is "DEFAULT"
   - ssh\_keypath, SSH public key, default is ~/.ssh/id\_rsa.pub
   - post\_create\_script, run a script on compute\_instance after deployment
   - proxy\_url, Connect via the specified proxy URL
   - user\_data, Add user data scripts

Optional settings for WinRM support in Windows:

   - setup\_winrm, Inject Windows powershell to set password and enable WinRM, default false.
   - winrm\_username, Used to set the WinRM transport username, defaults to 'opc'.
   - winrm\_password, Set the winrm password.  By default a randomly generated password will be used, so don't set this unless you have to.  Beware that the password must meet the Windows password complexity requirements otherwise the bootstrapping procedure will fail silently and Kitchen will eventually time out.

The use\_private\_ip influences whether the public or private IP will be used by Kitchen to connect to the instance.  If it is set to false (the default) then it will connect to the public IP, otherwise it'll use the private IP.

If the subnet\_id refers to a subnet configured to disallow public IPs on any attached VNICs, then the VNIC will be created without a public IP and the use\_private\_ip flag will assumed to be true irrespective of the config setting.  On subnets that do allow a public IP a public IP will be allocated to the VNIC, but the use\_private\_ip flag can still be used to override whether the private or public IP will be used.

```
---
driver:
  name: oci

provisioner:
  name: chef_zero
  always_update_cookbooks: true

verifier:
  name: inspec

platforms:
  - name: ubuntu-16.04
    driver:
      # These are mandatory
      compartment_id: "ocid1.compartment.oc1..xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      availability_domain: "XyAb:US-ASHBURN-AD-1"
      image_id: "ocid1.image.oc1.phx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      shape: "VM.Standard1.2"
      subnet_id: "ocid1.subnet.oc1.phx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

      # These are optional
      use_private_ip: false
      oci_config_file: "~/.oci/config"
      oci_profile_name: "DEFAULT"
      ssh_keypath: "~/.ssh/id_rsa.pub"
      post_create_script: >-
        touch /tmp/example.txt;
    transport:
      username: "ubuntu"

suites:
  - name: default
    run_list:
      - recipe[my_cookbook::default]
    verifier:
      inspec_tests:
        - test/smoke/default
    attributes:
```

## Support for user data scripts and cloud-init

The driver has support for adding user data that can be executed as scripts by cloud-init.  These can either be specified inline or by referencing a file.  Examples:

```
      user_data:
        - type: x-shellscript
          inline: |
            #!/bin/bash
            touch /tmp/foo.txt
          filename: init.sh
        - type: x-shellscript
          path: myscript.sh
          filename: myscript.sh
```

The `filename` parameter must be specified for each entry, and determines the destination filename for the script.  If the user data is to be read from a file then the `path` parameter should be specified to indicate where the file is to be read from.

The scripts will be encoded into a gzipped, base64 encoded multipart mime message and added as user data when launching the instance.

## Proxy support

If running Kitchen on a private subnet with no public IPs permitted, it may be necessary to connect to the OCI API via a web proxy.  The proxy URL can either be specified on the command line:
```
# With authentication
export http_proxy=http://<proxy_user>:<proxy_password>@<proxy_host>:<proxy_port>"
# Without authentication
export http_proxy=http://<proxy_host>:<proxy_port>"
```
.. or if preferred in the cookbook's .kitchen.yml file.
```
driver:
  ...
  proxy_url: "http://<proxy_user>:<proxy_password>@<proxy_host>:<proxy_port>"
```

The SSH transport can also be tunneled via the web proxy using the CONNECT http method, but note that this is not handled by the kitchen-oci gem.  Configuration is provided here for convenience only:

```
transport:
  username: "<os_username>"
  ssh_http_proxy: "<proxy_host>"
  ssh_http_proxy_port: <proxy_port>
  ssh_http_proxy_user: <proxy_user>
  ssh_http_proxy_password: <proxy_password>
```

## Windows Support

When launching Oracle provided Windows images, it may be helpful to allow Kitchen-oci to inject powershell to configure WinRM and to set a randomized password that does not need to be changed on first login.  If the `setup_winrm` parameter is set to true then the following steps will happen:

  - A random password will be generated and stored into the Kitchen state
  - A powershell script will be generated which sets the password for whatever username is defined in the transport section.
  - The script, along with any other user data, will be added to the user data and passed to the new instance.
  - The random password will be injected into the WinRM transport.

Make sure that the transport name is set to `winrm` and that the os\_type in the driver is set to `windows`.  See the following example.

Full example (.kitchen.yml):

```
---
driver:
  name: oci

provisioner:
  name: chef_zero
  always_update_cookbooks: true

verifier:
  name: inspec

platforms:
  - name: windows
    os_type: windows
    driver:
      # These are mandatory
      compartment_id: ocid1.compartment.oc1..aaaaaaaa...
      availability_domain: UhTe:PHX-AD-1
      image_id: ocid1.image.oc1.phx.aaaaaaaa...
      shape: VM.Standard2.2
      subnet_id: ocid1.subnet.oc1.phx.aaaaaaaa...

      # These are optional
      use_private_ip: false
      oci_config_file: ~/.oci/config
      oci_profile_name: DEFAULT
      ssh_keypath: "/home/<user>/.ssh/id_rsa.pub"

      # This optional, but for Windows only
      setup_winrm: true
      winrm_username: opc
    transport:
      name: winrm

suites:
  - name: default
    run_list:
      - recipe[my_cookbook::default]
    verifier:
      inspec_tests:
        - test/smoke/default
    attributes:
```

## Maintainer

Created and maintained by Stephen Pearson (<stephen.pearson@oracle.com>)

## License

Apache 2.0
