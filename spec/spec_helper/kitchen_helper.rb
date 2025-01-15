# frozen_string_literal: true

RSpec.shared_context "kitchen", :kitchen do
  let(:driver) { Kitchen::Driver::Oci.new(driver_config) }
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { Kitchen::Platform.new(name: "fooos-99") }
  let(:transport)     { Kitchen::Transport::Dummy.new }
  let(:provisioner)   { Kitchen::Provisioner::Dummy.new }
  let(:instance) do
    instance_double(
      Kitchen::Instance,
      name: "kitchen-foo",
      logger: logger,
      transport: transport,
      provisioner: provisioner,
      platform: platform,
      to_str: "str"
    )
  end
end
