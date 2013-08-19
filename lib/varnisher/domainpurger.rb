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
    # Initialises the purger
    #
    # @param domain [String] The hostname to purge
    def initialize(domain)
      @domain = domain
    end

    # Executes the purge request
    #
    # @return [True, False] True of the purge was successful, false if
    #   it wasn't
    def purge
      purged = Varnisher.purge(@domain, :domain)

      if purged
        Varnisher.log.info "Purged #{@domain}"
      else
        Varnisher.log.info "Failed to purge #{@domain}"
      end

      purged
    end
  end
end
