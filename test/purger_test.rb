require_relative 'test_helper'

describe Varnisher::Purger do
  it "successfully purges a URL" do
    stub_request(:purge, 'http://www.example.com/foo')
      .to_return(:status => 200)

    purger = Varnisher::Purger.new('PURGE', '/foo', 'www.example.com')
    assert purger.send
  end

  it "successfully purges a domain" do
    stub_request(:domainpurge, 'http://www.example.com/')
      .to_return(:status => 200)

    purger = Varnisher::Purger.new('DOMAINPURGE', '/', 'www.example.com')
    assert purger.send
  end

  it "handles a failed purge" do
    stub_request(:purge, 'http://www.example.com/foo')
      .to_return(:status => 501)

    purger = Varnisher::Purger.new('PURGE', '/foo', 'www.example.com')
    refute purger.send
  end

  it "handles a failed domain purge" do
    stub_request(:domainpurge, 'http://www.example.com/')
      .to_return(:status => 501)

    purger = Varnisher::Purger.new('DOMAINPURGE', '/', 'www.example.com')
    refute purger.send
  end

  it "handles timeouts" do
    stub_request(:purge, 'http://www.example.com/foo').to_timeout

    purger = Varnisher::Purger.new('PURGE', '/foo', 'www.example.com')
    refute purger.send
  end
end
