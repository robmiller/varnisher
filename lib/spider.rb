require 'rubygems'
require 'hpricot'
require 'net/http'
require 'parallel'

# Still playing with this number. On slow backends (which we're
# likely to be dealing with after a purge), a high number of 
# threads can be used; on fast backends, less can — but I'm not
# sure to what extent that gives a performance hit.
THREADS = 32

module VarnishToolkit
  class Spider

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

  	def queue_link(url)
  		@to_visit << url
  	end

  	def crawl_page(url)
  		# Don't crawl a page twice
  		return if @visited.include? url

  		begin
        uri = URI.parse(URI.encode(url.to_s.strip))
      rescue
        return
      end
      
      headers = {
        "User-Agent"     => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_2) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.106 Safari/535.2",
        "Accept-Charset" => "utf-8", 
        "Accept"         => "text/html"
      }

      begin
        doc = Hpricot(Net::HTTP.get_response(uri).body)
      rescue
        return
      end

      @pages_hit += 1

      if $options[:verbose]
        puts "Fetched #{url}..."
      end

      # Looks like a valid document! Let's parse it for links
      doc.search("//a[@href]").each { |e|
          href = e.get_attribute("href")

          # If we're dealing with a host-relative URL (e.g. <img src="/foo/bar.jpg">), absolutify it.
          if href.to_s =~ /^\//  
            href = uri.scheme + "://" + uri.host + href.to_s
          end

          # If we're dealing with a path-relative URL, make it relative to the current directory.
          if !(url.to_s =~ /[a-z]+:\/\//)
            # Take everything up to the final / in the path to be the current directory.
            /^(.*)\//.match(uri.path)
            href = uri.scheme + "://" + uri.host + $1 + "/" + href.to_s
          end

          begin
            href_uri = URI.parse(href)
          rescue
            next
          end

          next if href_uri.host != uri.host
          next if href_uri.scheme != 'http'
          next if @visited.include? href
          next if @to_visit.include? href

          @to_visit << href
      }

  		# Let's not hit this again
  		@visited << url
  	end

  	def spider
  		Parallel.map(@to_visit, :in_threads => THREADS) { |url|
          # We've crawled too many pages
          next if @pages_hit > $options[:num_pages] && $options[:num_pages] >= 0

  	      crawl_page(url)
  	    }
  	end
  end
end