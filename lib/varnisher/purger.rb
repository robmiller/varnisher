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
      begin
        uri = URI.parse(URI.encode(url.to_s.strip))
      rescue
        return false
      end

      method = "PURGE"
      path = uri.path
      host = uri.host
    else
      type = :domain

      method = "DOMAINPURGE"
      path = "/"
      host = target
    end

    s = TCPSocket.open(Varnisher.options['hostname'], Varnisher.options['port'])
    s.print("#{method} #{path} HTTP/1.1\r\nHost: #{host}\r\n\r\n")

    purged = ( s.read =~ /HTTP\/1\.1 200 Purged\./ )

    s.close

    purged
  end
end
