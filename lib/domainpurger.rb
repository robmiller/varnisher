require 'net/http'

# This requires a special bit of VCL:
#
# if ( req.request == "DOMAINPURGE" ) {
# 	if ( client.ip ~ auth ) {
# 		ban("obj.http.x-host == " + req.http.host);
# 		error 200 "Purged.";
# 	}
# }

module VarnishToolkit
  class DomainPurger
    def initialize(domain)
      s = TCPSocket.open(PROXY_HOSTNAME, PROXY_PORT)
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