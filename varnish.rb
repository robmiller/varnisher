#!/usr/bin/ruby
require 'optparse'
require 'lib/pagepurger'
require 'lib/domainpurger'

$options = {}

optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: varnish.rb [options] action target'

  opts.on('-h', '--help', 'Display this help') do
    puts opts
  end

  $options[:verbose] = false 
  opts.on('-v', '--verbose', 'Output more information') do
    $options[:verbose] = true
  end

  $options[:hostname] = 'localhost'
  opts.on('-H', '--hostname HOSTNAME', 'Hostname/IP address of your Varnish server. Default is localhost') do |hostname|
    $options[:hostname] = hostname
  end

  $options[:port] = 80
  opts.on('-p', '--port PORT', 'Port your Varnish server is listening on. Default is 80') do |port|
    $options[:port] = port
  end

end

optparse.parse!

# All our libs use these constants.
PROXY_HOSTNAME = $options[:hostname]
PROXY_PORT = $options[:port].to_i

if ( ARGV.length < 2 )
  puts "You must specify both an action and a target."
end

action = ARGV[0]
target = ARGV[1]

case action
  when "purge"
    # If target is a valid URL, then assume we're purging a page and its contents.
    if target =~ /^[a-z]+:\/\//
      PagePurger.new target
    end

    # If target is a hostname, assume we want to purge an entire domain.
    if target =~ /^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$/
      DomainPurger.new target
    end
end