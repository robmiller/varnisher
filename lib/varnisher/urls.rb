module Varnisher
  # A collection for URLs, that exposes some useful behaviour (like
  # selecting only URLs that have a given hostname, or converting
  # relative URLs to absolute).
  class Urls
    include Enumerable
    extend Forwardable

    # Given an array of URLs (either strings or URI objects), store them
    # in the collection.
    def initialize(urls = [])
      @urls = Array(urls)
    end

    # Coerces the values of the current collection into being URI
    # objects, which allows strings to be passed initially.
    def make_uris
      @urls = urls.map do |url|
        begin
          URI(u)
        rescue
          nil
        end
      end

      @urls = urls.compact
    end

    # Given a relative URL and a base to work from, will return the
    # absolute form of that URL.
    #
    # For example:
    #
    #   absolute_url('http://www.example.com', '/foo')
    #   # => "http://www.example.com/foo"
    #
    #   absolute_url('http://www.example.com/foo', 'bar')
    #   # => "http://www.example.com/bar"
    #
    #   absolute_url('http://www.example.com/foo/bar', 'baz')
    #   # => "http://www.example.com/foo/baz"
    def absolute_url(base, url)
      URI.join(base, URI.escape(url.to_s))
    end

    # Returns a new collection containing absolute versions of all the
    # URLs in the current collection.
    def make_absolute(base)
      Urls.new(urls.map { |uri| absolute_url(base, uri) })
    end

    # Returns a new collection containing only the URLs in this
    # collection that match the given hostname.
    def with_hostname(hostname)
      Urls.new(urls.select { |uri| uri.scheme == 'http' && uri.host == hostname })
    end

    # Returns a new collection containing the URLs in the current
    # collection, normalised according to their hash.
    def without_hashes
      normalised = urls.group_by do |url|
        url.fragment = nil
        url
      end

      Urls.new(normalised.keys)
    end

    # Returns a new collection containing the URLs in the current
    # collection without their query string values.
    def without_query_strings
      normalised = urls.group_by do |h|
        url.query = nil
        url
      end

      Urls.new(normalised.keys)
    end

    # Allows the addition of two collections by accessing the underlying
    # array.
    def +(other)
      Urls.new(urls + other.urls)
    end

    def_delegators :urls, :each, :<<, :length, :empty?

    protected
    attr_reader :urls
  end
end
