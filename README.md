# Kitchen::OCI

A Test Kitchen Driver for Oracle Bare Metal Cloud

WARNING: This is alpha quality.  Use at your own risk!

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

These settings are optional:

   - oci\_config\_file, by default this is ~/.oci/config
   - oci\_profile\_name, default value is "DEFAULT"
   - ssh\_keypath, default is ~/.ssh/id\_rsa.pub
   - post\_create\_script, does not run a script by default

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
      availability_domain: "ad1"
      compartment_id: "ocid1.compartment.oc1..xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      image_id: "ocid1.image.oc1.phx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      shape: "VM.Standard1.2"
      subnet_id: "ocid1.subnet.oc1.phx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      post_create_script: >-
        touch /tmp/example.txt;
    transport:
      username: "opc"

suites:
  - name: default
    run_list:
      - recipe[my_cookbook::default]
    verifier:
      inspec_tests:
        - test/smoke/default
    attributes:
```

Created and maintained by [Stephen Pearson][author] (<stevieweavie@gmail.com>)

## License

Apache 2.0
