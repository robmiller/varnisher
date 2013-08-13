require_relative 'varnisher/spider'
require_relative 'varnisher/domainpurger'
require_relative 'varnisher/pagepurger'

# This module is a namespace for our main functionality:
#
# * {Varnisher::Spider}
# * {Varnisher::DomainPurger}
# * {Varnisher::PagePurger}
module Varnisher 
  def self.options
    @options
  end

  def self.options=(options)
    @options = options
  end
end

