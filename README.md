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

Created and maintained by Stephen Pearson (<stevieweavie@gmail.com>)

## License

Apache 2.0
