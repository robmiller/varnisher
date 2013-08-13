require 'rubygems'
require 'hpricot'
require 'net/http'
require 'parallel'

module Varnisher
  # Crawls a website, following links that it finds along the way, until
  # it either runs out of pages to visit or reaches the limit of pages
  # that you impose on it.
  #
  # The spider is multithreaded, which means that one slow request won't
  # prevent the rest of your requests from happening; this is often the
  # case when the cached resources are a combination of static or
  # near-static resources (like CSS and images) and slow, dynamically
  # generated pages.
  #
  # The spider's behaviour can be configured somewhat, so that for
  # example it ignores query strings (treating /foo?foo=bar and
  # /foo?foo=baz as the same URL), or doesn't ignore hashes (so /foo#foo
  # and /foo#bar will be treated as different URLs).
  #
  #
  class Spider

    # Starts a new spider instance.
    #
    # Once it's done a bit of housekeeping and verified that the URL is
    # acceptable, it calls {#spider} to do the actual fetching of the
    # pages.
    #
    # @param url [String, URI] The URL to begin the spidering from. This
    #   also restricts the spider to fetching pages only on that
    #   (sub)domain — so, for example, if you specify
    #   http://example.com/foo as your starting page, only URLs that begin
    #   http://example.com will be followed.
    def initialize(url)
      if url =~ /^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$/
        url = 'http://' + url
      end

      @uri = URI.parse(url)

      @pages_hit = 0

      @visited = []
      @to_visit = []

      puts "Beginning spider of #{url}"
      crawl_page(url)
      spider
      puts "Done; #{@pages_hit} pages hit."
    end

    # Adds a link to the queue of pages to be visited.
    #
    # Doesn't perform any duplication-checking; however, {#crawl_page}
    # will refuse to crawl pages that have already been visited, so you
    # can safely queue links blindly and trust that {#crawl_page} will do
    # the de-duping for you.
    #
    # @api private
    def queue_link(url)
      @to_visit << url
    end

    # Visits a page, and extracts the links that it finds there.
    #
    # Links can be in the href attributes of HTML anchor tags, or they
    # can just be URLs that are mentioned in the content of the page;
    # the spider is flexible about what it crawls.
    #
    # Each link that it finds will be added to the queue of further
    # pages to visit.
    #
    # If the URL given sends an HTTP redirect, that redirect will be
    # followed; this is done by recursively calling `crawl_page` with
    # a decremented `redirect_limit`; if `redirect_limit` reaches 0, the
    # request will be abandoned.
    #
    # @param url [String, URI] The URL of the page to fetch
    # @param redirect_limit [Fixnum] The number of HTTP redirects to
    #   follow before abandoning this URL
    #
    # @api private
    def crawl_page(url, redirect_limit = 10)
      # Don't crawl a page twice
      return if @visited.include? url

      # Let's not hit this again
      @visited << url

      begin
        uri = URI.parse(URI.encode(url.to_s.strip))
      rescue
        return
      end

      headers = {
        "User-Agent"     => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_3) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.43 Safari/537.31",
        "Accept-Charset" => "ISO-8859-1,utf-8;q=0.7,*;q=0.3",
        "Accept"         => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      }

      begin
        req = Net::HTTP::Get.new(uri.path, headers)
        response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }

        case response
        when Net::HTTPRedirection
          return crawl_page(response['location'], redirect_limit - 1)
        when Net::HTTPSuccess
          doc = Hpricot(response.body)
        end
      rescue
        return
      end

      @pages_hit += 1

      if Varnisher.options["verbose"]
        puts "Fetched #{url}..."
      end

      find_links(doc, url) do |link|
        next if @visited.include? link
        next if @to_visit.include? link

        @to_visit << link
      end
    end

    # Given an hpricot document, will return all the links in that
    # document.
    #
    # "Links" are defined, for now, as the contents of the `href`
    # attributes on HTML `<a>` tags, and URLs that are mentioned in
    # comments.
    #
    # @param doc An hpricot document
    # @param url [String, URI] The URL that the document came from;
    #   this is used to resolve relative URIs
    #
    # @api private
    def find_links(doc, url)
      return unless doc.respond_to? 'search'

      begin
        uri = URI.parse(URI.encode(url.to_s.strip))
      rescue
        return
      end

      hrefs = []

      # Looks like a valid document! Let's parse it for links
      doc.search("//a[@href]").each do |e|
        hrefs << e.get_attribute("href")
      end

      # Let's also look for commented-out URIs
      doc.search("//comment()").each do |e|
        e.to_html.scan(/https?:\/\/[^\s\"]*/) { |url| hrefs << url; }
      end

      hrefs.each do |href|
          # Skip mailto links
          next if href =~ /^mailto:/

          # If we're dealing with a host-relative URL (e.g. <img
          # src="/foo/bar.jpg">), absolutify it.
          if href.to_s =~ /^\//
            href = uri.scheme + "://" + uri.host + href.to_s
          end

          # If we're dealing with a path-relative URL, make it relative
          # to the current directory.
          unless href.to_s =~ /[a-z]+:\/\//

            # Take everything up to the final / in the path to be the
            # current directory.
            if uri.path =~ /\//
              /^(.*)\//.match(uri.path)
              path = $1
            # If we're on the homepage, then we don't need a path.
            else
              path = ""
            end

            href = uri.scheme + "://" + uri.host + path + "/" + href.to_s
          end

          # At this point, we should have an absolute URL regardless of
          # its original format.

          # Strip hash links
          if ( Varnisher.options["ignore-hashes"] )
            href.gsub!(/(#.*?)$/, '')
          end

          # Strip query strings
          if ( Varnisher.options["ignore-query-strings"] )
            href.gsub!(/(\?.*?)$/, '')
          end

          begin
            href_uri = URI.parse(href)
          rescue
            # No harm in this — if we can't parse it as a URI, it
            # probably isn't one (`javascript:` links, etc.) and we can
            # safely ignore it.
            next
          end

          next if href_uri.host != uri.host
          next unless href_uri.scheme =~ /^https?$/

          yield href
      end
    end

    # Kicks off the spidering process.
    #
    # Fires up Parallel in as many threads as have been configured, and
    # begins to visit the pages in turn.
    #
    # This method is also responsible for checking whether the page
    # limit has been reached and, if it has, ending the spidering.
    #
    # @api private
    def spider
      threads = Varnisher.options["threads"]
      num_pages = Varnisher.options["num-pages"]

      Parallel.in_threads(threads) { |thread_number|
          # We've crawled too many pages
          next if @pages_hit > num_pages && num_pages >= 0

          while @to_visit.length > 0 do
            begin
              url = @to_visit.pop
            end while ( @visited.include? url )

            crawl_page(url)
          end
        }
    end
  end
end
