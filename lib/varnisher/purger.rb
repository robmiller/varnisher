module Varnisher
  module HTTP
    # Adds the custom verb "PURGE" to the Net::HTTP library, allowing calls
    # to:
    #
    #     Net::HTTP.new(host, port).request(Varnisher::HTTP::Purge.new(uri))
    class Purge < Net::HTTPRequest
      METHOD = "PURGE"
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    # Adds the custom verb "DOMAINPURGE" to the Net::HTTP library, allowing
    # calls to:
    #
    #     Net::HTTP.new(host, port).request(Varnisher::HTTP::DomainPurge.new(uri))
    class DomainPurge < Net::HTTPRequest
      METHOD = "DOMAINPURGE"
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end
  end
end

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
      @request_method = method == "PURGE" ? Varnisher::HTTP::Purge : Varnisher::HTTP::DomainPurge
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
      hostname = Varnisher.options['hostname'] || @host
      port = Varnisher.options['port']

      @path = '/' if @path.nil? || @path == ''

      begin
        http = Net::HTTP.new(hostname, port)
        response = http.request(@request_method.new(@path))
      rescue Timeout::Error
        return false
      end

      response.code == "200"
    end
  end
end
