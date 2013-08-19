require_relative 'test_helper'

require 'letters'

describe Varnisher::DomainPurger do
  before do
    Varnisher.options = { 'quiet' => true }

    @purger = Varnisher::DomainPurger.new('www.example.com')
  end

  it "it successfully purges a domain" do
    stub_request(:domainpurge, 'http://www.example.com/')
      .to_return(:status => 200)

    assert @purger.purge
  end

  it "it handles failed purges" do
    stub_request(:domainpurge, 'http://www.example.com/')
      .to_return(:status => 501)

    refute @purger.purge
  end
end
