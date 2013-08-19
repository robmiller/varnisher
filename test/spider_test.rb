require_relative 'test_helper'

describe Varnisher::Spider do
  before do
    stub_request(:get, 'http://www.example.com/foo')
      .to_return(
        :body => File.new(File.dirname(__FILE__) + "/data/spider.html"),
        :status => 200
      )

    Varnisher.options = { 'quiet' => true }

    @spider = Varnisher::Spider.new('http://www.example.com/foo')
    @spider.crawl_page(URI.parse('http://www.example.com/foo'))
  end

  it "visits the first page" do
    assert @spider.visited.include?('http://www.example.com/foo')
  end

  it "extracts page-relative links" do
    assert @spider.to_visit.include?(URI.parse('http://www.example.com/bar'))
  end

  it "extracts hostname-relative links" do
    assert @spider.to_visit.include?(URI.parse('http://www.example.com/baz'))
  end

  it "extracts absolute URLs" do
    assert @spider.to_visit.include?(URI.parse('http://www.example.com/foo/bar'))
  end

  it "ignores URLs on different hostnames" do
    refute @spider.to_visit.include?(URI.parse('http://www.example.net/foo'))
  end

  it "crawls all queued pages" do
    stub_request(:any, /www.example.com.*/)
      .to_return(:status => 200)

    @spider.run

    expected_urls = [
      'http://www.example.com/foo',
      'http://www.example.com/bar',
      'http://www.example.com/baz',
      'http://www.example.com/foo/bar',
    ]

    expected_urls.each do |url|
      assert_requested :get, url
    end
  end
end
