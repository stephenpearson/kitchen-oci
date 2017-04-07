# Kitchen::OracleBMC

A Test Kitchen Driver for Oracle Bare Metal Cloud

WARNING: This is alpha quality.  Use at your own risk!

## Prerequisites

You need an ssh keypair defined for your current user.  By default the driver
expects to find the public key in ~/.ssh/id_rsa.pub, but this can be
overridden in .kitchen.yml.

You need to create suitable configuration for BMC in ~/.oraclebmc but this
can be created using the CLI:
```
bmcs setup config
```

In the cloud console, ensure that you have a suitable compartment defined,
an external subnet, and security rules that allow incoming SSH and outgoing
HTTP (to allow Kitchen to pull the Chef binaries).

## Building the gem

Ensure you have the ChefDK installed.

```
eval "$(chef shell-init bash)"
gem build kitchen-oraclebmc.gemspec
gem install kitchen-oraclebmc-0.1.0.dev.gem
```

## Example .kitchen.yml

Adjust below template as required.  Today only OCID is supported
when specifying compartments, images, and subnets.  Look them up
in the console or CLI to find them.

```
---
driver:
  name: oraclebmc

provisioner:
  name: chef_zero
  always_update_cookbooks: true

verifier:
  name: inspec

platforms:
  - name: ubuntu-16.04
    driver:
      availability_domain: "xxx"
      compartment_id: "ocid1.compartment.oc1..xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      image_id: "ocid1.image.oc1.phx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      shape: "VM.Standard1.1"
      subnet_id: "ocid1.subnet.oc1.phx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      post_create_script: >-
        sleep 60;
        while sudo fuser -s /var/lib/dpkg/lock 2>/dev/null;
          do sleep 1;
        done
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

Created and maintained by [Stephen Pearson][author] (<stevieweavie@gmail.com>)

## License

Apache 2.0
