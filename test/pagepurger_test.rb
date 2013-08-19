require_relative 'test_helper'

describe Varnisher::PagePurger do
  before do
    Varnisher.options = { 'quiet' => true }

    stub_request(:any, %r(http://www\.example\.com/.*))
      .to_return(:status => 200)

    stub_request(:get, 'http://www.example.com/foo')
      .to_return(
        :body => File.new(File.dirname(__FILE__) + '/data/pagepurger.html'),
        :status => 200
      )

    @purger = Varnisher::PagePurger.new('http://www.example.com/foo')
    @purger.purge
  end

  it "fetches the original page" do
    assert_requested :get, 'http://www.example.com/foo'
  end

  it "purges stylesheets" do
    assert @purger.urls.include?(URI.parse('http://www.example.com/page-relative.css'))
    assert @purger.urls.include?(URI.parse('http://www.example.com/foo/hostname-relative.css'))
    assert @purger.urls.include?(URI.parse('http://www.example.com/absolute.css'))
  end

  it "ignores external stylesheets" do
    refute @purger.urls.include?(URI.parse('http://www.example.net/external.css'))
  end

  it "purges images" do
    assert @purger.urls.include?(URI.parse('http://www.example.com/page-relative.png'))
    assert @purger.urls.include?(URI.parse('http://www.example.com/foo/hostname-relative.png'))
    assert @purger.urls.include?(URI.parse('http://www.example.com/absolute.png'))
  end

  it "ignores external images" do
    refute @purger.urls.include?(URI.parse('http://www.example.net/external.png'))
  end

  it "purges JavaScript files" do
    assert @purger.urls.include?(URI.parse('http://www.example.com/page-relative.js'))
    assert @purger.urls.include?(URI.parse('http://www.example.com/foo/hostname-relative.js'))
    assert @purger.urls.include?(URI.parse('http://www.example.com/absolute.js'))
  end

  it "ignores external JavaScript files" do
    refute @purger.urls.include?(URI.parse('http://www.example.net/external.js'))
  end
end
