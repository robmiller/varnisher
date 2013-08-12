require 'net/http'

module Varnisher
  # Purges an entire domain from the Varnish cache.
  #
  # This requires a special bit of VCL in your Varnish configuration:
  #
  #     if ( req.request == "DOMAINPURGE" ) {
  #       if ( client.ip ~ auth ) {
  #         ban("obj.http.x-host == " + req.http.host);
  #         error 200 "Purged.";
  #       }
  #     }
  class DomainPurger
    # Executes the purge request.
    #
    # @param domain [String] The hostname to purge
    def initialize(domain)
      s = TCPSocket.open($options['hostname'], $options['port'])
      s.print("DOMAINPURGE / HTTP/1.1\r\nHost: #{domain}\r\n\r\n")

      if s.read =~ /HTTP\/1\.1 200 Purged\./
        puts "Purged  #{domain}"
      else
        puts "Failed to purge #{domain}"
      end

      s.close
    end
  end
end
