# frozen_string_literal: true

RSpec.shared_context "proxy", :proxy do |rspec|
  before do
    stub_const("ENV", ENV.to_hash.merge({ "http_proxy" => "http://myfakeproxy.com", "no_proxy" => ".myfakedomain.com" }))
    allow(OCI::ApiClientProxySettings).to receive(:new).with("myfakeproxy.com", 80).and_return(proxy_settings)
  end
  let(:proxy_settings) { OCI::ApiClientProxySettings.new("myfakeproxy.com", 80) }
end
