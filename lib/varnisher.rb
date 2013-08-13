require_relative 'varnisher/spider'
require_relative 'varnisher/purger'
require_relative 'varnisher/domainpurger'
require_relative 'varnisher/pagepurger'

require 'logger'

# This module is a namespace for our main functionality:
#
# * {Varnisher::Spider}
# * {Varnisher::DomainPurger}
# * {Varnisher::PagePurger}
module Varnisher 
  # Our default options are set here; they can be overriden either by
  # command-line arguments or by settings in a user's ~/.varnishrc file.
  @options = {
    'verbose' => false,
    'quiet' => false,
    'hostname' => nil,
    'port' => 80,
    'num-pages' => -1,
    'threads' => 16,
    'ignore-hashes' => true,
    'ignore-query-strings' => false,
    'log' => nil
  }

  @log = Logger.new(STDOUT)
  # By default, only display the log message, nothing else.
  @log.formatter = proc { |_, _, _, msg| "#{msg}\n" }

  def self.options
    @options
  end

  def self.options=(options)
    @options = options

    if options['hostname'].nil? and options['target']
      begin
        uri = URI.parse(options['target'])
        options['hostname'] = uri.host
      rescue
      end
    end

    @log.level = if options['verbose']
                   Logger::DEBUG
                 elsif options['quiet']
                   Logger::FATAL
                 else
                   Logger::INFO
                 end
  end

  def self.log
    @log
  end
end

