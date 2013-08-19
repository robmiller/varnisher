require 'rubygems'
require 'nokogiri'
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
    attr_reader :to_visit, :visited

    # Starts a new spider instance.
    #
    # Once it's done a bit of housekeeping and verified that the URL is
    # acceptable, it calls {#spider} to do the actual fetching of the
    # pages.
    #
    # @param url [String, URI] The URL to begin the spidering from. This
    #   also restricts the spider to fetching pages only on that
    #   (sub)domain - so, for example, if you specify
    #   http://example.com/foo as your starting page, only URLs that begin
    #   http://example.com will be followed.
    def initialize(url)
      # If we've been given only a hostname, assume that we want to
      # start spidering from the homepage
      url = 'http://' + url unless url =~ %r(^[a-z]+://)

      @uri = URI.parse(url)

      @visited = []
      @to_visit = []
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
    # @param url [String, URI] The URL of the page to fetch
    #
    # @api private
    def crawl_page(uri)
      # Don't crawl a page twice
      return if @visited.include? uri.to_s

      # Let's not hit this again
      @visited << uri.to_s

      doc = Nokogiri::HTML(Net::HTTP.get_response(uri).body)

      Varnisher.log.debug "Fetched #{uri}..."

      find_links(doc, uri).each do |link|
        next if @visited.include? link
        next if @to_visit.include? link

        @to_visit << link
      end
    end

    # Given a Nokogiri document, will return all the links in that
    # document.
    #
    # "Links" are defined, for now, as the contents of the `href`
    # attributes on HTML `<a>` tags, and URLs that are mentioned in
    # comments.
    #
    # @param doc A Nokogiri document
    # @param url [String, URI] The URL that the document came from;
    #   this is used to resolve relative URIs
    #
    # @return [Array] An array of URIs
    #
    # @api private
    def find_links(doc, uri)
      hrefs = []

      hrefs  = get_anchors(doc)
      hrefs += get_commented_urls(doc)

      hrefs = valid_urls(hrefs, uri)
      hrefs = remove_hashes(hrefs)
      hrefs = remove_query_strings(hrefs)

      hrefs
    end

    # Given an HTML document, will return all the URLs that exist as
    # href attributes of anchor tags.
    #
    # @return [Array] An array of strings
    def get_anchors(doc)
      doc.xpath('//a[@href]').map { |e| e['href'] }
    end

    # Given an HTML document, will return all the URLs that exist in
    # HTML comments, e.g.:
    #
    #     <!-- http://example.com/foo/bar -->
    def get_commented_urls(doc)
      doc.xpath('//comment()').flat_map { |e| URI.extract(e.to_html, 'http') }
    end

    # Given a set of URLs, will return only the ones that are valid for
    # spidering.
    #
    # That means URLs that have the same hostname as the hostname we
    # started from, and that are on the HTTP scheme rather than HTTPS
    # (since Varnish doesn't support HTTPS).
    #
    # Additionally, some normalisation will be performed, so that the
    # URLs are absolute (using the page that they were fetched from as
    # the base, just like a browser would).
    #
    # @return [Array] An array of URIs
    def valid_urls(hrefs, uri)
      hrefs.map { |u| URI.join(uri, URI.escape(u)) }
        .select { |u| u.scheme == 'http' && u.host == @uri.host }
    end

    # Given a set of URLs, will normalise them according to their URL
    # minus the hash; that is, normalise them so that:
    #
    # foo#bar
    #
    # and:
    #
    # foo#baz
    #
    # Are considered the same.
    #
    # @return [Array] An array of URIs
    def remove_hashes(hrefs)
      return hrefs unless Varnisher.options['ignore-hashes']

      hrefs = hrefs.group_by do |h|
        URI.parse(h.scheme + '://' + h.host + h.path.to_s + h.query.to_s)
      end

      hrefs.keys
    end

    # Given a set of URLs, will normalise them according to their URL
    # minus the query string; that is, normalise them so that:
    #
    # foo?foo=bar
    #
    # and:
    #
    # foo?foo=baz
    #
    # Are considered the same.
    #
    # @return [Array] An array of URIs
    def remove_query_strings(hrefs)
      return hrefs unless Varnisher.options['ignore-query-strings']

      hrefs = hrefs.group_by do |h|
        URI.parse(h.scheme + '://' + h.host + h.path.to_s)
      end

      hrefs.keys
    end

    # Pops a URL from the queue of yet-to-be-visited URLs, ensuring that
    # it's not one that we've visited before.
    #
    # @return [URI] A URI object for an unvisited page
    def pop_url
      url = ''

      loop do
        url = @to_visit.pop
        break unless @visited.include?(url)
      end

      url
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
    def run
      Varnisher.log.info "Beginning spider of #{@uri}"

      crawl_page(@uri)

      threads = Varnisher.options['threads']
      num_pages = Varnisher.options['num-pages']

      Parallel.in_threads(threads) do |thread_number|
        next if @visited.length > num_pages && num_pages >= 0

        crawl_page(pop_url) while @to_visit.length > 0
      end

      Varnisher.log.info "Done; #{@visited.length} pages hit."
    end
  end
end
