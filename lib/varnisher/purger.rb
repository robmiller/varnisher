module Varnisher
  # Sends a purge request to the Varnish server
  #
  # It does this by sending an HTTP request with a custom method; either
  # PURGE, if the specified target is a URL, or DOMAINPURGE if the
  # specified target is a hostname.
  #
  # This naturally relies on you having your Varnish config prepared
  # appropriately, so that the actual purge will take place when we send
  # these requests.
  #
  # @param target [String, URI] The URL or hostname to purge
  # @param type [:page, :domain] Whether to do a purge of an individual
  #   URL or a whole hostname
  # @return [true, false] True if we received an acceptable response
  #   from the server; false otherwise
  def self.purge(target, type = :page)
    if type == :page
      purger = Purger.from_url(target)
    else
      purger = Purger.new('DOMAINPURGE', '/', target)
    end

    purger.send if purger
  end

  # Responsible for sending purge requests to the Varnish server.
  class Purger
    # Prepares a new purge request.
    #
    # @param method ["PURGE", "DOMAINPURGE"] The HTTP verb to send to
    #   the server
    # @param path [String] The path to purge; for a domain purge,
    #   use "/"
    # @param host [String] The hostname of the URL being purged
    def initialize(method, path, host)
      @method = method
      @path = path
      @host = host
    end

    def self.from_url(url)
      begin
        uri = URI.parse(URI.encode(url.to_s.strip))
      rescue
        return
      end

      new('PURGE', uri.path, uri.host)
    end

    def send
      hostname = Varnisher.options['hostname']
      port = Varnisher.options['port']

      TCPSocket.open(hostname, port) do |s|
        s.print("#{@method} #{@path} HTTP/1.1\r\nHost: #{@host}\r\n\r\n")
        !!s.read.match(/HTTP\/1\.1 200 Purged\./)
      end
    end
  end
end
