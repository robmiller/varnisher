#!/usr/bin/ruby
require 'rubygems'
require 'hpricot'
require 'net/http'
require 'parallel'

PROCESSES = 4
if ( ENV['VARNISH_PROXY_HOSTNAME'] )
  PROXY = ENV['VARNISH_PROXY_HOSTNAME']
else
  PROXY     = 'proxy1.cloud.bigfish.co.uk'
end

class Purger
  
  def initialize(url)
    @url = url
    @uri = URI.parse(url)
    
    @urls = []
    
    # First, purge the URL itself; that means we'll get up-to-date references within that page.
    puts "Purging #{@url}...\n\n"
    purge(@url)
    
    # Then, do a fresh GET of the page and queue any resources we find on it.
    puts "Looking for external resources on #{@url}...\n\n"
    find_resources(@url)
    puts "\n#{@urls.length} total resources found.\n\n"

    if @urls.length == 0
      puts "No resources found. Abort!"
      return
    end
    
    # Let's figure out which of these resources we can actually purge — whether they're on our server, etc.
    puts "Tidying resources...\n"
    tidy_resources
    puts "#{@urls.length} purgeable resources found.\n\n"
    
    # Now, purge all of the resources we just queued.
    puts "Purging resources...\n\n"
    purge_queue
    
    puts "\nNothing more to do!\n\n"
  end
  
  # Sends a PURGE request to the Varnish server, asking it to purge the given URL from its cache.
  def purge(url)
    begin
      uri = URI.parse(URI.encode(url.to_s.strip))
    rescue
      puts "Couldn't parse URL for purging: #{$!}"
      return
    end
    
    s = TCPSocket.open(PROXY, 80)
    s.print("PURGE #{uri.path} HTTP/1.1\r\nHost: #{uri.host}\r\n\r\n")

    response = s.read
    if /HTTP\/1\.1 200 Purged\./.match(response)
      puts "Purged  #{url}"
    else
      puts "Failed to purge #{url}"
    end

    s.close
  end
  
  # Fetches a page and parses out any external resources (e.g. JavaScript files, images, CSS files) it finds on it.
  def find_resources(url)
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
      doc = Hpricot(Net::HTTP.get_response(uri).body)
    rescue
      puts "Hmm, I couldn't seem to fetch that URL. Sure it's right?\n"
      return
    end

    # Stylesheets
    doc.search("link[@rel*=stylesheet]").each { |e|
      href = e.get_attribute('href')
      puts "Found stylesheet: #{href}"
      queue_resource(href)
    }

    # JavaScript files
    doc.search("script[@src]").each { |e|
      src = e.get_attribute('src')
      puts "Found JavaScript file: #{src}"
      queue_resource(src)
    }
    
    # Images
    doc.search("img[@src]").each { |e|
      src = e.get_attribute('src')
      puts "Found image file: #{src}"
      queue_resource(src)
    }    
  end
  
  # Adds a URL to the processing queue.
  def queue_resource(url)
    @urls << url.to_s
  end
  
  def tidy_resources
    valid_urls = []
    
    @urls.each { |url|
      # If we're dealing with a host-relative URL (e.g. <img src="/foo/bar.jpg">), absolutify it.
      if /^\//.match(url.to_s)
        url = @uri.scheme + "://" + @uri.host + url.to_s
      end

      # If we're dealing with a path-relative URL, make it relative to the current directory.
      if !/[a-z]+:\/\//.match(url.to_s)
        # Take everything up to the final / in the path to be the current directory.
        /^(.*)\/.*$/.match(@uri.path)
        url = @uri.scheme + "://" + @uri.host + $1 + "/" + url.to_s
      end
      
      begin
        uri = URI.parse(url)
      rescue
        return
      end
      
      # Skip URLs that aren't HTTP, or that are on different domains.
      next if uri.scheme != "http"
      next if uri.host != @uri.host
      
      valid_urls << url
    }
    
    @urls = valid_urls.dup
  end
  
  # Processes the queue of URLs, sending a purge request for each of them.
  def purge_queue()
    Parallel.map(@urls, :in_processes => PROCESSES) { |url|
      puts "Purging #{url}..."
      purge(url)
      # sleep 3
    }
  end

end

exit if ARGV.length == 0

Purger.new(ARGV[0])