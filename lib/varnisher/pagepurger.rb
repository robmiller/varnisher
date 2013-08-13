require 'rubygems'
require 'nokogiri'
require 'net/http'
require 'parallel'

module Varnisher
  # Purges an individual URL from Varnish.
  class PagePurger

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

      # First, purge the URL itself; that means we'll get up-to-date
      # references within that page.
      puts "Purging #{@url}...\n\n"
      purge(@url)

      # Then, do a fresh GET of the page and queue any resources we find on it.
      puts "Looking for external resources on #{@url}..."

      if Varnisher.options["verbose"]
        puts "\n\n"
      end

      fetch_page(@url)

      if Varnisher.options["verbose"]
        puts "\n"
      end

      puts "#{@urls.length} total resources found.\n\n"

      if @urls.length == 0
        puts "No resources found. Abort!"
        return
      end

      # Let's figure out which of these resources we can actually purge
      # — whether they're on our server, etc.
      puts "Tidying resources...\n"
      tidy_resources
      puts "#{@urls.length} purgeable resources found.\n\n"

      # Now, purge all of the resources we just queued.
      puts "Purging resources..."

      if Varnisher.options["verbose"]
        puts "\n\n"
      end

      purge_queue

      if Varnisher.options["verbose"]
        puts "\n"
      end

      puts "Nothing more to do!\n\n"
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
    # [purging-and-banning]: https://www.varnish-cache.org/docs/3.0/tutorial/purging.html
    #
    # @api private
    def purge(url)
      begin
        uri = URI.parse(URI.encode(url.to_s.strip))
      rescue
        puts "Couldn't parse URL for purging: #{$!}"
        return
      end

      s = TCPSocket.open(Varnisher.options['hostname'], Varnisher.options['port'])
      s.print("PURGE #{uri.path} HTTP/1.1\r\nHost: #{uri.host}\r\n\r\n")

      if Varnisher.options["verbose"]
        if s.read =~ /HTTP\/1\.1 200 Purged\./
          puts "Purged  #{url}"
        else
          puts "Failed to purge #{url}"
        end
      end

      s.close
    end

    # Fetches a page and parses out any external resources (e.g.
    # JavaScript files, images, CSS files) it finds on it.
    #
    # @param url [String, URI]
    #
    # @api private
    def fetch_page(url)
      begin
        uri = URI.parse(URI.encode(url.to_s.strip))
      rescue
        puts "Couldn't parse URL for resource-searching: #{url}"
        return
      end

      headers = {
        "User-Agent"     => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_2) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.106 Safari/535.2",
        "Accept-Charset" => "utf-8",
        "Accept"         => "text/html"
      }

      begin
        doc = Nokogiri::HTML(Net::HTTP.get_response(uri).body)
      rescue
        puts "Hmm, I couldn't seem to fetch that URL. Sure it's right?\n"
        return
      end

      find_resources(doc) do |resource|
        if Varnisher.options["verbose"]
            puts "Found #{resource}"
          end
        queue_resource(resource)
      end
    end

    # Given a Nokogiri document, will return an array of the resources
    # within that document.
    #
    # Resources include things like CSS files, images, and JavaScript
    # files.
    #
    # If a block is given, the block will be executed once for each
    # resource.
    #
    # @param doc A Nokogiri document
    #
    # @return [Array] An array of strings, each representing a URL
    #
    # @api private
    def find_resources(doc)
      return unless doc.respond_to? 'xpath'

      # A bash at an abstract representation of resources. All you need
      # is an XPath, and what attribute to select from the matched
      # elements.
      res = Struct.new :name, :selector, :attribute
      res_defs = [
        res.new('stylesheet', 'link[rel~=stylesheet]', 'href'),
        res.new('JavaScript file', 'script[src]', 'src'),
        res.new('image file', 'img[src]', 'src')
      ]

      resources = []

      res_defs.each do |resource|
        doc.css(resource.selector).each do |e|
          att = e[resource.attribute]
          yield att if block_given?
          resources << att
        end
      end

      resources
    end

    # Adds a URL to the processing queue.
    #
    # @param url [String]
    #
    # @api private
    def queue_resource(url)
      @urls << url.to_s
    end

    # Tidies up the resource queue, converting relative URLs to
    # absolute.
    #
    # @return [Array] The new URLs
    #
    # @api private
    def tidy_resources
      valid_urls = []

      @urls.each { |url|

        # If we're dealing with a host-relative URL (e.g. <img
        # src="/foo/bar.jpg">), absolutify it.
        if url.to_s =~ /^\//
          url = @uri.scheme + "://" + @uri.host + url.to_s
        end

        # If we're dealing with a path-relative URL, make it relative to
        # the current directory.
        unless url.to_s =~ /[a-z]+:\/\//

          # Take everything up to the final / in the path to be the
          # current directory.
          /^(.*)\//.match(@uri.path)
          url = @uri.scheme + "://" + @uri.host + $1 + "/" + url.to_s
        end

        begin
          uri = URI.parse(url)
        rescue
          next
        end

        # Skip URLs that aren't HTTP, or that are on different domains.
        next if uri.scheme != "http"
        next if uri.host != @uri.host

        valid_urls << url
      }

      @urls = valid_urls.dup
    end

    # Processes the queue of URLs, sending a purge request for each of
    # them.
    #
    # @api private
    def purge_queue
      Parallel.map(@urls) do |url|
        if Varnisher.options["verbose"]
          puts "Purging #{url}..."
        end

        purge(url)
      end
    end

  end
end
