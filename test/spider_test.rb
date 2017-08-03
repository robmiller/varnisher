require_relative 'test_helper'

describe Varnisher::Spider do
  before do
    stub_request(:get, 'http://www.example.com/foo')
      .to_return(
        :body => File.new(File.dirname(__FILE__) + "/data/spider.html"),
        :status => 200
      )
  end

  describe "with standard options" do
    before do
      Varnisher.options = { 'quiet' => true }

      @spider = Varnisher::Spider.new('http://www.example.com/foo')
      @spider.crawl_page(URI.parse('http://www.example.com/foo'))
    end

    it "visits the first page" do
      assert @spider.visited.include?('http://www.example.com/foo')
    end

    it "extracts page-relative links" do
      assert_includes @spider.to_visit, URI.parse('http://www.example.com/bar')
    end

    it "extracts hostname-relative links" do
      assert_includes @spider.to_visit, URI.parse('http://www.example.com/baz')
    end

    it "extracts absolute URLs" do
      assert_includes @spider.to_visit, URI.parse('http://www.example.com/foo/bar')
    end

    it "ignores URLs on different hostnames" do
      refute_includes @spider.to_visit, URI.parse('http://www.example.net/foo')
    end

    it "reads URLs from comments" do
      assert_includes @spider.to_visit, URI.parse('http://www.example.com/commented')
    end

    it "ignores external URLs in comments" do
      refute_includes @spider.to_visit, URI.parse('http://www.example.net/commented')
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

  describe 'with options' do
    describe 'with css-selectors' do
      before do
        Varnisher.options = { 'quiet' => true, 'filter-by-css' => 'div.important-container' }

        @spider = Varnisher::Spider.new('http://www.example.com/foo')
        @spider.crawl_page(URI.parse('http://www.example.com/foo'))
      end

      it 'extracts urls inside the css class selector (includes urls from comments)' do
        expected_urls = [
          URI.parse('http://www.example.com/sir'),
          URI.parse('http://www.example.com/zar'),
          URI.parse('http://www.example.com/commented')
        ]

        expected_urls.each do |url|
          assert_includes @spider.to_visit, url
        end
      end

      it 'ignores urls outside the css class selector' do
        non_expected_urls = [
          URI.parse('http://www.example.com/bar'),
          URI.parse('http://www.example.com/baz'),
          URI.parse('http://www.example.com/foo/bar'),
          URI.parse('http://www.example.net/foo')
        ]

        non_expected_urls.each do |url|
          refute_includes @spider.to_visit, url
        end
      end
    end
  end
end
