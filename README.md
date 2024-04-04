# Kitchen::OCI

A Test Kitchen Driver for Oracle Cloud Infrastructure (OCI)

## Prerequisites

You need an ssh keypair defined for your current user.  By default the driver
expects to find the public key in ~/.ssh/id\_rsa.pub, but this can be
overridden in .kitchen.yml.

You need to create suitable configuration for OCI in ~/.oci/config and this
can be created using the CLI:
```bash
oci setup config
```

Ensure that you have a suitable compartment defined, an external subnet, and
security rules that allow incoming SSH and outgoing HTTP to allow Kitchen to
pull the Chef binaries.

## Building the gem

This step is only necessary if you wish to make local modifications.  The gem
has already been published to rubygems.org.

```bash
rake build
```

## Installing the gem

You must install the gem into whatever Ruby is used to run kitchen.  On a
workstation this will likely be the Chef Workstation environment.  To switch to
Chef Workstation if you haven't already:

```bash
eval "$(chef shell-init bash)"
```

You can install the gem from RubyGems.org with:

```bash
gem install kitchen-oci
```

To install a gem you built yourself:

```bash
gem install pkg/kitchen-oci-<VERSION>.gem
```

## Testing

Ensure you have Chef Workstation installed and initialized.  From the root of this project, execute `bundle install`.
Set the following environment variables in your shell:

```bash
COMPARTMENT_ID
AVAILABILITY_DOMAIN
SUBNET_ID
STANDARD_SHAPE
FLEX_SHAPE
LIN_IMAGE_ID
WIN_IMAGE_ID
```

These environment variables should align with your tenancy and the region in which you intend to test.

There is a kitchen.yml file in the `test/integration/fixtures` directory in this project that can be used to test the gem. From this
directory, execute `bundle exec kitchen list` to see a list of instances.  All normal kitchen commands work within the `bundle exec`
context from here.

## Example kitchen.yml

Adjust below template as required.  The following configuration is mandatory for all instance types:

   - `compartment_id` or `compartment_name`
   - `availability_domain`
   - `shape`
   - `subnet_id`

There is an additional configuration item that allows for toggling instance types.  If this item is not included, it defaults to `compute`.

   - Permitted values of `instance_type`:
      - compute
      - dbaas

Note: The availability domain should be the full AD name including the tenancy specific prefix.  For example: "AaBb:US-ASHBURN-AD-1".  Look in the OCI console to get your tenancy specific string.

### Compute Instance Type

The following configuration is mandatory:

   - `image_id`, The ocid of the desired image\
OR 
   - `image_name`, The display name of the desired image

Image ocids and display names can be found on the public [OCI Documentation / Images](https://docs.oracle.com/en-us/iaas/images/) page. The `image_name` property allows you to specify the display
name of the image rather than the ocid.  There are two ways to do this:

- specify the entire image name.  For example, `Oracle-Linux-8.9-2024.02.26-0`
- specify the un-dated, un-versioned portion of the display name. For example, `Oracle-Linux-8.9`\
     Note: for aesthetics, the dashes can be replaced with spaces `Oracle Linux 8.9`. Both ways work, one way is prettier.

If the second option is chosen (providing a portion of the display name), the behavior is to search all display names that match the string provided plus anything that looks like
a date, then sort by time created and return the ocid for the newest one. This allows you to always get the latest version of a given image without having to continually update your kitchen.yml files.

Only specify one of `image_id` or `image_name`.  If both are provided, the value specified by `image_id` will always win.

These settings are optional:

   - `boot_volume_size_in_gbs`, The size of the boot volume, in GB (range: 50GB - 32TB)
   - `use_private_ip`, Whether to connect to the instance using a private IP (default: `false`) (public ip)
   - `oci_config_file`, OCI configuration file, by default this is ~/.oci/config
   - `oci_profile_name`, OCI profile to use (default: `DEFAULT`)
   - `oci_config`, Hash of additional `OCI::Config` settings. Allows you to test without an oci config file (see below)
   - `ssh_keypath`, SSH public key (default: `~/.ssh/id\_rsa.pub`)
   - `post_create_script`, run a script on compute\_instance after deployment
   - `proxy_url`, Connect via the specified proxy URL
   - `user_data`, Add user data scripts
   - `hostname_prefix`, Prefix for the generated hostnames (note that OCI doesn't like underscores)
   - `defined_tags`, Hash containing tag name(s) and values(s). Each key must be predefined and scoped into a namespace.
   - `freeform_tags`, Hash containing tag name(s) and values(s)
   - `use_instance_principals`, Boolean flag indicated whether Instance Principals should be used as credentials (see below) (default: `false`)
   - `use_token_auth`, Boolean flag indicating if token authentication should be used (see below) (default: `false`)
   - `preemptible_instance`, Boolean flag to indicate if the compute instance should be preemptible (default: `false`)
   - `shape_config`, Hash of shape config parameters required when using Flex shapes.
     - `ocpus`, number of CPUs requested
     - `memory_in_gbs`, the amount of memory requested
     - `baseline_ocpu_utilization`, the minimum CPU utilization (default: `BASELINE_1_1`)
   - `volumes`, an array of hashes with configuration options of each volume
     - `name`, the display name of the volume
     - `size_in_gbs`, the size in Gbs for the volume. (minimum value: 50GB)
     - `type`, oracle only supports `iscsi` or `paravirtual` options (default: `paravirtual`)
     - `vpus_per_gb`, vpus per gb. Make sure to consult the documentation for your shape to take advantage of UHP as MultiPath is enabled only with certain combinations of memory/cpus.
   - `nsg_ids`, The option to connect up to 5 Network Security Groups to compute instance.
   - `custom_metadata`, Add metadata to the compute instance request
   - `all_plugins_disabled`, Whether Oracle Cloud Agent can run all the available plugins (default: `false`)
   - `management_disabled`, Whether Oracle Cloud Agent can run all the available management plugins (default: `false`)
   - `monitoring_disabled`, Whether Oracle Cloud Agent can gather performance metrics and monitor the instance using the monitoring plugins (default: `false`)

Optional settings for WinRM support in Windows:

   - `setup_winrm`, Inject Windows powershell to set password and enable WinRM (default: `false`)
   - `winrm_username`, Used to set the WinRM transport username (default: `opc`)
   - `winrm_password`, Set the winrm password.  By default a randomly generated password will be used, so don't set this unless you have to.  Beware that the password must meet the Windows password complexity requirements otherwise the bootstrapping procedure will fail silently and Kitchen will eventually time out.

The `use_private_ip` influences whether the public or private IP will be used by Kitchen to connect to the instance.  If it is set to false (the default) then it will connect to the public IP, otherwise it'll use the private IP.

If the `subnet_id` refers to a subnet configured to disallow public IPs on any attached VNICs, then the VNIC will be created without a public IP and the `use_private_ip` flag will assumed to be true irrespective of the config setting.  On subnets that do allow a public IP a public IP will be allocated to the VNIC, but the `use_private_ip` flag can still be used to override whether the private or public IP will be used.

```yml
---
  driver:
    name: oci
    # These are mandatory
    compartment_name: "dev-00"
    availability_domain: "XyAb:US-ASHBURN-AD-1"
    image_id: "ocid1.image.oc1.phx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    shape: "VM.Standard1.2"
    subnet_id: "ocid1.subnet.oc1.phx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

    # These are optional
    use_private_ip: false
    oci_config_file: "~/.oci/config"
    oci_profile_name: "DEFAULT"
    ssh_keypath: "~/.ssh/id_rsa.pub"
    nsg_ids:
      - ocid1.networksecuritygroup.oc1.phx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      - ocid1.networksecuritygroup.oc1.phx.yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
    custom_metadata:
      key1: value1
      key2: value2
    post_create_script: >-
```

### DBaaS Instance Type

The DBaaS instance type configuration should be written in a hash beginning with `dbaas`.

The following configuration item is mandatory for the DBaaS `instance_type`:

   - `db_version`, The specific version of the Oracle database software to be installed. Values can be at either the major version level (eg. 12.1.0.2) or at a PSU level (eg. 12.1.0.2.191015). If no PSU is provided, the latest available will be installed.

The following is a list of optional items for the DBaaS `instance_type`:

   - `cpu_core_count`, CPU core count for DBaaS nodes (default: `2`)
   - `database_edition`, The edition of the Oracle database software to be installed (default: `ENTERPRISE_EDITION`)
   - `license_model`, The licensing model for the Oracle database software. (default: `BRING_YOUR_OWN_LICENSE`)
   - `db_name`, The name of the database to be provisioned.  Must be 8 characters or less, alphanumeric (default: `dbaas1`)
   - `pdb_name`, The name of the pdb to be provisioned.  Only valid if `db_version` is 12cR1 or higher (default: `nil` OCI will create a single pdb with the name `db_name`\_PDB1)
   - `admin_password`, The SYS password of the database to be provisioned.  Password must be 9 to 30 characters and contain at least 2 uppercase, 2 lowercase, 2 special, and 2 numeric characters. The special characters must be `_`, `#`, or `-`. If not provided, a random password will be generated.
   - `initial_data_storage_size_in_gb`, The desired amount of database storage in GB (default: `256`)
   - `character_set`, The characterset of the database (default: `AL32UTF8`)
   - `ncharacter_set`, The national characterset of the database (default: `AL16UTF16`)
   - `db_workload`, The desired workload configuration for the database.  Acceptable values are `OLTP` and `DSS`. (default: `OLTP`)

Note: At this time, `node_count` is forced to be 1.  RAC provisioning is not supported.

```yml
---
  driver:
    name: oci
    instance_type: dbaas
    ...
    dbaas:
      db_version: "12.1.0.2.191015"
```

## Instance Principals

If you are launching Kitchen from a compute instance running in OCI then you might prefer to use Instance Principals to authenticate to the OCI APIs.  To set this up you can omit the `oci_config_file` and `oci_profile_name` settings and insert `use_instance_principals: true` into your .kitchen.yml instead.

```yml
platforms:
  - name: ubuntu-18.04
    driver:
      ...
      use_instance_principals: true
      ...
```

__Important__: If you want to configure a proxy when using Instance Principals, ensure you define the `no_proxy` environment variable so that all link-local access bypasses the proxy.  For example:

```sh
export no_proxy=169.254.0.0/16
```

This will allow the OCI lib to retrieve the certificate, key and ca-chain from the metadata service.

## Token Auth

If you are launching Kitchen from system configured for token authentication (by running `oci session authenticate`), you need to set `use_token_auth: true`. This is in addition to the `oci_config_file` and `oci_profile_name` settings.

```yml
platforms:
  - name: ubuntu-18.04
    driver:
      ...
      oci_config_file: "~/.oci/config"
      oci_profile_name: "DEFAULT"
      use_token_auth: true
      ...
```

## Use without OCI config file

If you want to run without running `oci setup config` (such as on a build server) you can specify configuration settings that would be in the `~/.oci/config` file directly in the `kitchen.yml`

For example, to use the [OCI CLI Environment Variables](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/clienvironmentvariables.htm) without a config you could have use kitchen's ERB to read environment variables.

```yml
platforms:
  - name: ubuntu-18.04
    driver:
      ...
      oci_config:
        region: <%= ENV['OCI_CLI_REGION'] %>
        user: <%= ENV['OCI_CLI_USER'] %>
        fingerprint: <%= ENV['OCI_CLI_FINGERPRINT'] %>
        authentication_type: <%= ENV['OCI_CLI_AUTH'] %>
        key_file: <%= ENV['OCI_CLI_KEY_FILE'] %>
        tenancy: <%= ENV['OCI_CLI_TENANCY'] %>
      ...
```


## Support for user data scripts and cloud-init

The driver has support for adding user data that can be executed as scripts by cloud-init.  These can either be specified inline or by referencing a file.  Examples:

```yml
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

Alternately, if you simply pass a string to the user_data, it will be base64 encoded and add as user data when launching the instance.

```yml
  user_data: |
    login: user1
    uid: 1000
    gid: 1000
```

## Proxy support

If running Kitchen on a private subnet with no public IPs permitted, it may be necessary to connect to the OCI API via a web proxy.  The proxy URL can either be specified on the command line:
```bash
# With authentication
export http_proxy=http://<proxy_user>:<proxy_password>@<proxy_host>:<proxy_port>"
# Without authentication
export http_proxy=http://<proxy_host>:<proxy_port>"
```
.. or if preferred in the cookbook's .kitchen.yml file.
```yml
driver:
  ...
  proxy_url: "http://<proxy_user>:<proxy_password>@<proxy_host>:<proxy_port>"
```

The SSH transport can also be tunneled via the web proxy using the CONNECT http method, but note that this is not handled by the kitchen-oci gem.  Configuration is provided here for convenience only:

```yml
transport:
  username: "<os_username>"
  ssh_http_proxy: "<proxy_host>"
  ssh_http_proxy_port: <proxy_port>
  ssh_http_proxy_user: <proxy_user>
  ssh_http_proxy_password: <proxy_password>
```

See also the section above on Instance Principals if you plan to use a proxy in conjunction with a proxy.  The proxy needs to be avoided when accessing the metadata address.

## Preemptible Instances

This will allow you to create a [preemptible instance](https://docs.oracle.com/en-us/iaas/Content/Compute/Concepts/preemptible.htm).  Preemptible instances behave the same as regular compute instances, but the capacity is reclaimed when it's needed elsewhere, and the instances are terminated. If your workloads are fault-tolerant and can withstand interruptions, then preemptible instances can reduce your costs.

```yml
---
driver:
  name: oci
  ...
  preemptible_instance: true
  ...
```

## Flex Shape Instances

This will allow you to launch a flexible shape instance.  A flexible shape lets you customize the number of CPUs and memory available when launching or resizing the VM.  Note that there are smaller number of shapes available and the image ocid must also be compatible.  Please consult [OCI documentation](https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm#flexible) to ensure the proper combination of shape and image ocid.

```yml
---
driver:
  name: oci
  ...
  shape_config:
    ocpus: 2
    memory_in_gbs: 8
    baseline_ocpu_utilization: BASELINE_1_1
  ...
```

The `baseline_ocpu_utilization` property is for a subcore burstable VM instance. Omit this attribute or use the `BASELINE_1_1` baseline for a non-burstable instance.
Supported values are: `BASELINE_1_8`, `BASELINE_1_2`, `BASELINE_1_1`

## Windows Support

When launching Oracle provided Windows images, it may be helpful to allow kitchen-oci to inject powershell to configure WinRM and to set a randomized password that does not need to be changed on first login.  If the `setup_winrm` parameter is set to true then the following steps will happen:

  - A random password will be generated and stored into the Kitchen state
  - A powershell script will be generated which sets the password for whatever username is defined in the transport section.
  - The script, along with any other user data, will be added to the user data and passed to the new instance.
  - The random password will be injected into the WinRM transport.

Make sure that the transport name is set to `winrm` and that the os\_type in the driver is set to `windows`.  See the following example.

Full example (.kitchen.yml):

```yml
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

Created by Stephen Pearson (<stephen.pearson@oracle.com>) maintained by Justin Steele (<justin.steele@oracle.com>) 

## License

Apache 2.0
