require 'rubygems'
require 'nokogiri'
require 'net/http'
require 'parallel'

module Varnisher
  # Purges an individual URL from Varnish.
  class PagePurger
    attr_reader :urls

    # A bash at an abstract representation of resources. All you need
    # is a selector, and what attribute to select from the matched
    # elements.
    Resource = Struct.new :name, :selector, :attribute
    def self.resources
      [
        Resource.new('stylesheet', 'link[rel~=stylesheet]', 'href'),
        Resource.new('JavaScript file', 'script[src]', 'src'),
        Resource.new('image file', 'img[src]', 'src')
      ]
    end

    # Purges the given URL from the Varnish cache.
    #
    # Will also purge all of the resources it finds on that page (e.g.
    # images, CSS files, JavaScript files, etc.)
    #
    # @param url [String, URI] The URL to purge
    def initialize(url)
      @url = url
      @uri = URI.parse(url)

      @urls = []
    end

    # Sends a PURGE request to the Varnish server, asking it to purge
    # the given URL from its cache.
    #
    # This presupposes that you have the following VCL in your Varnish
    # config file:
    #
    #     if (req.request == "PURGE") {
    #       if ( client.ip ~ auth ) {
    #         ban("obj.http.x-url == " + req.url + " && obj.http.x-host == " + req.http.host);
    #         error 200 "Purged.";
    #       }
    #     }
    #
    # More about purging can be found
    # [in the Varnish documentation][purging-and-banning].
    #
    # [purging-and-banning]: http://varnish-cache.org/docs/3.0/tutorial/purging.html
    #
    # @api private
    def purge
      Varnisher.log.info "Purging #{@url}..."

      purged = Varnisher.purge(@url)
      if purged
        Varnisher.log.info ''
        Varnisher.log.debug "Purged #{@url}"
      else
        Varnisher.log.info "Failed to purge #{@url}\n"
      end

      purge_resources
    end

    # Purges all the resources on the given page.
    def purge_resources
      fetch_page

      return if @urls.empty?

      tidy_resources
      purge_queue
    end

    # Fetches a page and parses out any external resources (e.g.
    # JavaScript files, images, CSS files) it finds on it.
    #
    # @api private
    def fetch_page
      Varnisher.log.info "Looking for external resources on #{@url}..."

      begin
        @doc = Nokogiri::HTML(Net::HTTP.get_response(@uri).body)
      rescue
        Varnisher.log.info "Hmm, I couldn't fetch that URL. Sure it's right?\n"
        return
      end

      @urls = find_resources

      Varnisher.log.debug ''
      Varnisher.log.info "#{@urls.length} total resources found.\n"
    end

    # Returns an array of resources contained within the current page.
    #
    # Resources include things like CSS files, images, and JavaScript
    # files.
    #
    # If a block is given, the block will be executed once for each
    # resource.
    #
    # @return [Array] An array of strings, each representing a URL
    #
    # @api private
    def find_resources
      found = []

      self.class.resources.each do |res|
        @doc.css(res.selector).each do |e|
          attribute = e[res.attribute]

          Varnisher.log.debug("Found resource: #{attribute}")

          yield attribute if block_given?
          found << attribute
        end
      end

      found
    end

    # Tidies up the resource queue, converting relative URLs to
    # absolute.
    #
    # @return [Array] The new URLs
    #
    # @api private
    def tidy_resources
      Varnisher.log.info 'Tidying resources...'

      @urls = @urls.map { |url| URI.join(@uri, url) }
        .select { |uri| uri.scheme == 'http' && uri.host == @uri.host }

      Varnisher.log.info "#{@urls.length} purgeable resources found.\n"
    end

    # Processes the queue of URLs, sending a purge request for each of
    # them.
    #
    # @api private
    def purge_queue
      Varnisher.log.info 'Purging resources...'

      Parallel.map(@urls) do |url|
        Varnisher.log.debug "Purging #{url}..."

        Varnisher.purge(url.to_s)
      end

      Varnisher.log.info 'Done.'
    end

  end
end
