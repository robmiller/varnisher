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
      purged = Varnisher.purge(domain, :domain)
      if purged
        Varnisher.log.info "Purged #{domain}"
      else
        Varnisher.log.info "Failed to purge #{domain}"
      end
    end
  end
end
