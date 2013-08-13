require_relative 'varnisher/spider'
require_relative 'varnisher/domainpurger'
require_relative 'varnisher/pagepurger'

# This module is a namespace for our main functionality:
#
# * {Varnisher::Spider}
# * {Varnisher::DomainPurger}
# * {Varnisher::PagePurger}
module Varnisher 
  # Our default options are set here; they can be overriden either by
  # command-line arguments or by settings in a user's ~/.varnishrc file.
  @options = {
    verbose: false,
    hostname: nil,
    port: 80,
    :'num-pages' => -1,
    threads: 16,
    :'ignore-hashes' => true,
    :'ignore-query-strings' => false
  }

  def self.options
    @options
  end

  def self.options=(options)
    @options = options
  end
end

