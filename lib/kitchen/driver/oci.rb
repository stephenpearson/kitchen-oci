# frozen_string_literal: true

#
# Author:: Stephen Pearson (<stephen.pearson@oracle.com>)
#
# Copyright (C) 2019, Stephen Pearson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# rubocop:disable Metrics/AbcSize

# This require fixes bug in ChefDK 4.0.60-1 on Linux.
require 'forwardable'
require 'base64'
require 'erb'
require 'kitchen'
require 'oci'
require 'openssl'
require 'uri'
require 'zlib'

module Kitchen
  module Driver
    # Oracle OCI driver for Kitchen.
    #
    # @author Stephen Pearson <stephen.pearson@oracle.com>
    class Oci < Kitchen::Driver::Base # rubocop:disable Metrics/ClassLength
      require_relative 'oci_version'
      require_relative 'mixins/oci_config'
      require_relative 'mixins/api'

      plugin_version Kitchen::Driver::OCI_VERSION

      # required config items
      required_config :availability_domain
      required_config :shape
      required_config :subnet_id

      # common config items
      default_config :oci_config, {}
      default_config :oci_config_file, nil
      default_config :oci_profile_name, nil
      default_config :compartment_id, nil
      default_config :compartment_name, nil
      default_config :instance_type, 'compute'
      default_config :image_id
      default_config :hostname_prefix do |hnp|
        hnp.instance.name
      end
      default_keypath = File.expand_path(File.join(%w[~ .ssh id_rsa.pub]))
      default_config :ssh_keypath, default_keypath
      default_config :post_create_script, nil
      default_config :proxy_url, nil
      default_config :user_data, nil
      default_config :freeform_tags, {}
      default_config :defined_tags, {}
      default_config :custom_metadata, {}
      default_config :use_instance_principals, false
      default_config :use_token_auth, false
      default_config :shape_config, {}
      default_config :nsg_ids, []

      # compute only configs
      default_config :setup_winrm, false
      default_config :winrm_user, 'opc'
      default_config :winrm_password, nil
      default_config :preemptible_instance, false
      default_config :boot_volume_size_in_gbs, nil
      default_config :use_private_ip, false
      default_config :volumes, {}

      # dbaas configs
      default_config :dbaas, {}

      validations[:instance_type] = lambda do |_attr, val, _driver|
        validation_error('instance_type must be either compute or dbaas') unless ['compute', 'dbaas'].include?(val.downcase)
      end

      validations[:nsg_ids] = lambda do |_attr, val, _driver|
        validation_error('config value for `nsg_ids` cannot be longer than 5 items') if val.length > 5
      end

      validations[:volumes] = lambda do |_attr, val, _driver|
        val.each do |vol_attr, _vol_value|
          unless ['iscsi', 'paravirtual', nil].include?(vol_attr[:type])
            validation_error("#{vol_attr[:type]} is not a valid volume type for #{vol_attr[:name]}")
          end
        end
      end

      def self.validation_error(message)
        warn message
        exit!
      end

      include Kitchen::Driver::Mixins::OciConfig
      include Kitchen::Driver::Mixins::Api

      def create(state)
        return if state[:server_id]

        validate_config!
        state = process_windows_options(state)

        instance_id = launch_instance(state)

        state[:server_id] = instance_id
        state[:hostname] = instance_ip(instance_id)

        instance.transport.connection(state).wait_until_ready

        state[:volumes] = process_volumes_list(state)
        state[:volume_attachments] = process_volume_attachments(state)

        return unless config[:post_create_script]

        info('Running post create script')
        script = config[:post_create_script]
        instance.transport.connection(state).execute(script)
      end

      def destroy(state)
        return unless state[:server_id]

        instance.transport.connection(state).close

        if state[:volume_attachments]
          state[:volume_attachments].each do |attachment|
            volume_detach(attachment)
          end
        end

        if state[:volumes]
          state[:volumes].each do |vol|
            volume_delete(vol[:id])
          end
        end

        if instance_type == 'compute'
          comp_api.terminate_instance(state[:server_id])
        elsif instance_type == 'dbaas'
          dbaas_api.terminate_db_system(state[:server_id])
        end

        state.delete(:server_id)
        state.delete(:hostname)
      end

      def process_freeform_tags(freeform_tags)
        prov = instance.provisioner.instance_variable_get(:@config)
        tags = %w[run_list policyfile]
        tags.each do |tag|
          freeform_tags[tag] = prov[tag.to_sym].join(',') unless prov[tag.to_sym].nil? || prov[tag.to_sym].empty?
        end
        freeform_tags[:kitchen] = true
        freeform_tags
      end

      def process_windows_options(state)
        state[:username] = config[:winrm_user] if config[:setup_winrm]
        if config[:setup_winrm] == true &&
           config[:password].nil? &&
           state[:password].nil?
          state[:password] = config[:winrm_password] || random_password
        end
        state
      end

      private

      def instance_type
        config[:instance_type].downcase
      end

      ##################
      # Common methods #
      ##################
      def launch_instance(state)
        if instance_type == 'compute'
          launch_compute_instance(state)
        elsif instance_type == 'dbaas'
          launch_dbaas_instance
        end
      end

      def public_ip_allowed?
        subnet = net_api.get_subnet(config[:subnet_id]).data
        !subnet.prohibit_public_ip_on_vnic
      end

      def instance_ip(instance_id)
        if instance_type == 'compute'
          compute_instance_ip(instance_id)
        elsif instance_type == 'dbaas'
          dbaas_instance_ip(instance_id)
        end
      end

      def pubkey
        if instance_type == 'compute'
          File.readlines(config[:ssh_keypath]).first.chomp
        elsif instance_type == 'dbaas'
          result = []
          result << File.readlines(config[:ssh_keypath]).first.chomp
        end
      end

      def generate_hostname
        prefix = config[:hostname_prefix]
        if instance_type == 'compute'
          [prefix, random_hostname(instance.name)].compact.join('-')
        elsif instance_type == 'dbaas'
          # 30 character limit for hostname in DBaaS
          if prefix.length >= 30
            [prefix[0, 26], 'db1'].compact.join('-')
          else
            [prefix, random_string(25 - prefix.length), 'db1'].compact.join('-')
          end
        end
      end

      def random_hostname(prefix)
        "#{prefix}-#{random_string(6)}"
      end

      def random_password
        if instance_type == 'compute'
          special_chars = %w[@ - ( ) .]
        elsif instance_type == 'dbaas'
          special_chars = %w[# _ -]
        end

        (Array.new(5) { special_chars.sample } +
         Array.new(5) { ('a'..'z').to_a.sample } +
         Array.new(5) { ('A'..'Z').to_a.sample } +
         Array.new(5) { ('0'..'9').to_a.sample }).shuffle.join
      end

      def random_string(length)
        Array.new(length) { ('a'..'z').to_a.sample }.join
      end

      def random_number(length)
        Array.new(length) { ('0'..'9').to_a.sample }.join
      end

      ###################
      # Compute methods #
      ###################
      def launch_compute_instance(state)
        request = compute_instance_request(state)
        response = comp_api.launch_instance(request)
        instance_id = response.data.id

        comp_api.get_instance(instance_id).wait_until(
          :lifecycle_state,
          OCI::Core::Models::Instance::LIFECYCLE_STATE_RUNNING
        )
        instance_id
      end

      def compute_instance_request(state)
        request = compute_launch_details

        inject_powershell(state) if config[:setup_winrm] == true

        metadata = {}
        md = config[:custom_metadata]
        md.each do |key, value|
          metadata.store(key, value)
        end
        metadata.store('ssh_authorized_keys', pubkey)
        data = user_data
        metadata.store('user_data', data) if config[:user_data] && !config[:user_data].empty?
        request.metadata = metadata
        request
      end

      def compute_launch_details # rubocop:disable Metrics/MethodLength
        OCI::Core::Models::LaunchInstanceDetails.new.tap do |l|
          hostname = generate_hostname
          l.availability_domain = config[:availability_domain]
          l.compartment_id = compartment_id
          l.display_name = hostname
          l.source_details = instance_source_details
          l.shape = config[:shape]
          l.create_vnic_details = create_vnic_details(hostname)
          l.freeform_tags = process_freeform_tags(config[:freeform_tags])
          l.defined_tags = config[:defined_tags]
          l.preemptible_instance_config = preemptible_instance_config if config[:preemptible_instance]
          l.shape_config = shape_config unless config[:shape_config].empty?
        end
      end

      def instance_source_details
        OCI::Core::Models::InstanceSourceViaImageDetails.new(
          sourceType: 'image',
          imageId: config[:image_id],
          bootVolumeSizeInGBs: config[:boot_volume_size_in_gbs],
        )
      end

      def preemptible_instance_config
        OCI::Core::Models::PreemptibleInstanceConfigDetails.new(
          preemption_action:
            OCI::Core::Models::TerminatePreemptionAction.new(
              type: 'TERMINATE', preserve_boot_volume: true
            )
        )
      end

      def shape_config
        OCI::Core::Models::LaunchInstanceShapeConfigDetails.new(
          ocpus: config[:shape_config][:ocpus],
          memory_in_gbs: config[:shape_config][:memory_in_gbs],
          baseline_ocpu_utilization: config[:shape_config][:baseline_ocpu_utilization] || 'BASELINE_1_1'
        )
      end

      def create_vnic_details(name)
        raise 'nsg_ids cannot have more than 5 NSGs.' if config[:nsg_ids].length > 5

        OCI::Core::Models::CreateVnicDetails.new(
          assign_public_ip: public_ip_allowed?,
          display_name: name,
          hostname_label: name,
          nsg_ids: config[:nsg_ids],
          subnetId: config[:subnet_id]
        )
      end

      def vnics(instance_id)
        vnic_attachments(instance_id).map do |att|
          net_api.get_vnic(att.vnic_id).data
        end
      end

      def vnic_attachments(instance_id)
        att = comp_api.list_vnic_attachments(
          compartment_id,
          instance_id: instance_id
        ).data

        raise 'Could not find any VNIC attachments' unless att.any?

        att
      end

      def compute_instance_ip(instance_id)
        vnic = vnics(instance_id).select(&:is_primary).first
        if public_ip_allowed?
          config[:use_private_ip] ? vnic.private_ip : vnic.public_ip
        else
          vnic.private_ip
        end
      end

      def winrm_ps1(state)
        filename = File.join(__dir__, %w[.. .. .. tpl setup_winrm.ps1.erb])
        tpl = ERB.new(File.read(filename))
        tpl.result(binding)
      end

      def inject_powershell(state)
        data = winrm_ps1(state)
        config[:user_data] ||= []
        config[:user_data] << {
          type: 'x-shellscript',
          inline: data,
          filename: 'setup_winrm.ps1'
        }
      end

      def read_part(part)
        if part[:path]
          content = File.read part[:path]
        elsif part[:inline]
          content = part[:inline]
        else
          raise 'Invalid user data'
        end
        content.split("\n")
      end

      def mime_parts(boundary)
        msg = []
        config[:user_data].each do |m|
          msg << "--#{boundary}"
          msg << "Content-Disposition: attachment; filename=\"#{m[:filename]}\""
          msg << 'Content-Transfer-Encoding: 7bit'
          msg << "Content-Type: text/#{m[:type]}" << 'Mime-Version: 1.0' << ''
          msg << read_part(m) << ''
        end
        msg << "--#{boundary}--"
        msg
      end

      def user_data # rubocop:disable Metrics/MethodLength
        if config[:user_data].is_a? Array
          boundary = "MIMEBOUNDARY_#{random_string(20)}"
          msg = ["Content-Type: multipart/mixed; boundary=\"#{boundary}\"",
                 'MIME-Version: 1.0', '']
          msg += mime_parts(boundary)
          txt = msg.join("\n") + "\n"
          gzip = Zlib::GzipWriter.new(StringIO.new)
          gzip << txt
          Base64.encode64(gzip.close.string).delete("\n")
        elsif config[:user_data].is_a? String
          Base64.encode64(config[:user_data]).delete("\n")
        end
      end

      ########################
      # BlockStorage methods #
      ########################
      def process_volumes_list(state)
        created_vol = []
        config[:volumes].each do |vol_settings|
          # convert to hash because otherwise it's an an OCI API Object and won't load
          volume_attachment_type = vol_settings[:type] ? vol_settings[:type].downcase : 'paravirtual'
          unless %w[iscsi paravirtual].include?(volume_attachment_type)
            info("invalid volume attachment type: #{volume_attachment_type}")
            next
          end
          volume = volume_create(
            config[:availability_domain],
            vol_settings[:name],
            vol_settings[:size_in_gbs],
            vol_settings[:vpus_per_gb] || 10
          ).to_hash
          # convert to string otherwise it's a ruby datetime object and won't load
          volume[:attachment_type] = volume_attachment_type
          created_vol << volume
        end
        created_vol
      end

      def volume_create(availability_domain, display_name, size_in_gbs, vpus_per_gb)
        info("Creating <#{display_name}>...")
        result = blockstorage_api.create_volume(
          OCI::Core::Models::CreateVolumeDetails.new(
            compartment_id: compartment_id,
            availability_domain: availability_domain,
            display_name: display_name,
            size_in_gbs: size_in_gbs,
            vpus_per_gb: vpus_per_gb
          )
        )
        get_volume_response = blockstorage_api.get_volume(result.data.id)
                                              .wait_until(:lifecycle_state, OCI::Core::Models::Volume::LIFECYCLE_STATE_AVAILABLE)
        info("Finished creating <#{display_name}>.")
        {
          id: get_volume_response.data.id,
          display_name: get_volume_response.data.display_name
        }
      end

      def volume_delete(volume_id)
        info("Deleting <#{volume_id}>...")
        blockstorage_api.delete_volume(volume_id)
        blockstorage_api.get_volume(volume_id)
                        .wait_until(:lifecycle_state, OCI::Core::Models::Volume::LIFECYCLE_STATE_TERMINATED)
        info("Finished deleting <#{volume_id}>.")
      end

      def process_volume_attachments(state)
        attachments = []
        state[:volumes].each do |volume|
          info("Attaching <#{volume[:display_name]}>...")
          details = volume_create_attachment_details(volume, state[:server_id])
          attachment = volume_attach(details).to_hash
          attachments << attachment
          info("Finished attaching <#{volume[:display_name]}>.")
        end
        attachments
      end

      def volume_create_attachment_details(volume, instance_id)
        if volume[:attachment_type].eql?('iscsi')
          OCI::Core::Models::AttachIScsiVolumeDetails.new(
            display_name: 'iSCSIAttachment',
            volume_id: volume[:id],
            instance_id: instance_id
          )
        elsif volume[:attachment_type].eql?('paravirtual')
          OCI::Core::Models::AttachParavirtualizedVolumeDetails.new(
            display_name: 'paravirtAttachment',
            volume_id: volume[:id],
            instance_id: instance_id
          )
        end
      end

      def volume_attach(volume_attachment_details)
        result = comp_api.attach_volume(volume_attachment_details)
        get_volume_attachment_response =
          comp_api.get_volume_attachment(result.data.id)
                  .wait_until(:lifecycle_state, OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_ATTACHED)
        state_data = {
          id: get_volume_attachment_response.data.id
        }
        if get_volume_attachment_response.data.attachment_type == 'iscsi'
          state_data.store(:iqn_ipv4, get_volume_attachment_response.data.ipv4)
          state_data.store(:iqn, get_volume_attachment_response.data.iqn)
          state_data.store(:port, get_volume_attachment_response.data.port)
        end
        state_data
      end

      def volume_detach(volume_attachment)
        info("Detaching <#{volume_attachment[:id]}>...")
        comp_api.detach_volume(volume_attachment[:id])
        comp_api.get_volume_attachment(volume_attachment[:id])
                .wait_until(:lifecycle_state, OCI::Core::Models::VolumeAttachment::LIFECYCLE_STATE_DETACHED)
        info("Finished detaching <#{volume_attachment[:id]}>.")
      end

      #################
      # DBaaS methods #
      #################
      def launch_dbaas_instance
        request = dbaas_launch_details
        response = dbaas_api.launch_db_system(request)
        instance_id = response.data.id

        dbaas_api.get_db_system(instance_id).wait_until(
          :lifecycle_state,
          OCI::Database::Models::DbSystem::LIFECYCLE_STATE_AVAILABLE,
          max_interval_seconds: 900,
          max_wait_seconds: 21600
        )
        instance_id
      end

      def dbaas_launch_details # rubocop:disable Metrics/MethodLength
        cpu_core_count = config[:dbaas][:cpu_core_count] ||= 2
        database_edition = config[:dbaas][:database_edition] ||= OCI::Database::Models::DbSystem::DATABASE_EDITION_ENTERPRISE_EDITION
        initial_data_storage_size_in_gb = config[:dbaas][:initial_data_storage_size_in_gb] ||= 256
        license_model = config[:dbaas][:license_model] ||= OCI::Database::Models::DbSystem::LICENSE_MODEL_BRING_YOUR_OWN_LICENSE

        OCI::Database::Models::LaunchDbSystemDetails.new.tap do |l|
          l.availability_domain = config[:availability_domain]
          l.compartment_id = compartment_id
          l.cpu_core_count = cpu_core_count
          l.database_edition = database_edition
          l.db_home = create_db_home_details
          l.display_name = [config[:hostname_prefix], random_string(4), random_number(2)].compact.join('-')
          l.hostname = generate_hostname
          l.shape = config[:shape]
          l.ssh_public_keys = pubkey
          l.cluster_name = generate_cluster_name
          l.initial_data_storage_size_in_gb = initial_data_storage_size_in_gb
          l.node_count = 1
          l.license_model = license_model
          l.subnet_id = config[:subnet_id]
          l.freeform_tags = process_freeform_tags(config[:freeform_tags])
          l.defined_tags = config[:defined_tags]
        end
      end

      def create_db_home_details
        raise 'db_version cannot be nil!' if config[:dbaas][:db_version].nil?

        OCI::Database::Models::CreateDbHomeDetails.new.tap do |l|
          l.database = create_database_details
          l.db_version = config[:dbaas][:db_version]
          l.display_name = ['dbhome', random_number(10)].compact.join('')
        end
      end

      def create_database_details # rubocop:disable Metrics/MethodLength
        character_set = config[:dbaas][:character_set] ||= 'AL32UTF8'
        ncharacter_set = config[:dbaas][:ncharacter_set] ||= 'AL16UTF16'
        db_workload = config[:dbaas][:db_workload] ||= OCI::Database::Models::CreateDatabaseDetails::DB_WORKLOAD_OLTP
        admin_password = config[:dbaas][:admin_password] ||= random_password
        db_name = config[:dbaas][:db_name] ||= 'dbaas1'

        OCI::Database::Models::CreateDatabaseDetails.new.tap do |l|
          l.admin_password = admin_password
          l.character_set = character_set
          l.db_name = db_name
          l.db_workload = db_workload
          l.ncharacter_set = ncharacter_set
          l.pdb_name = config[:dbaas][:pdb_name]
          l.db_backup_config = db_backup_config
        end
      end

      def db_backup_config
        OCI::Database::Models::DbBackupConfig.new.tap do |l|
          l.auto_backup_enabled = false
        end
      end

      def generate_cluster_name
        prefix = config[:hostname_prefix].split('-')[0]
        # 11 character limit for cluster_name in DBaaS
        if prefix.length >= 11
          prefix[0, 11]
        else
          [prefix, random_string(10 - prefix.length)].compact.join('-')
        end
      end

      def dbaas_node(instance_id)
        dbaas_api.list_db_nodes(
          compartment_id,
          db_system_id: instance_id
        ).data
      end

      def dbaas_vnic(node_ocid)
        dbaas_api.get_db_node(node_ocid).data
      end

      def dbaas_instance_ip(instance_id)
        vnic = dbaas_node(instance_id).select(&:vnic_id).first.vnic_id
        if public_ip_allowed?
          net_api.get_vnic(vnic).data.public_ip
        else
          net_api.get_vnic(vnic).data.private_ip
        end
      end
    end
  end
end

# rubocop:enable Metrics/AbcSize
