# frozen_string_literal: true

module Kitchen
  module Driver
    class Oci
      # generic class for instance models
      class Instance < Oci
        require_relative '../../driver/mixins/oci_config'
        require_relative '../../driver/mixins/api'
        require_relative '../../driver/mixins/support'
        require_relative 'models/compute'
        require_relative 'models/dbaas'

        include Kitchen::Driver::Mixins::OciConfig
        include Kitchen::Driver::Mixins::Api
        include Kitchen::Driver::Mixins::Support

        attr_accessor :config, :state

        def initialize(config, state)
          super()
          @config = config
          @state = state
        end

        def launch_instance
          add_common_props
          add_specific_props
          launch(launch_details)
        end

        def terminate_instance
          terminate(state[:server_id])
        end

        private

        # stuff all instances get
        def add_common_props
          launch_details.tap do |l|
            l.availability_domain = config[:availability_domain]
            l.compartment_id = compartment_id
            l.freeform_tags = freeform_tags
            l.defined_tags = config[:defined_tags]
            l.shape = config[:shape]
          end
        end

        def freeform_tags
          tags = %w[run_list policyfile]
          fft = config[:freeform_tags]
          tags.each do |tag|
            unless fft[tag.to_sym].nil? || fft[tag.to_sym].empty?
              fft[tag] =
                prov[tag.to_sym].join(',')
            end
          end
          fft[:kitchen] = true
          fft
        end

        def public_ip_allowed?
          subnet = net_api.get_subnet(config[:subnet_id]).data
          !subnet.prohibit_public_ip_on_vnic
        end
      end
    end
  end
end
