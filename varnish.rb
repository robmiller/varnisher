#!/usr/bin/ruby
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require 'optparse'
require 'yaml'
require_relative 'lib/pagepurger'
require_relative 'lib/domainpurger'
require_relative 'lib/spider'

$options = {
  :verbose             => false,
  :hostname            => 'localhost',
  :port                => 80,
  :num_pages           => 100,
  :ignore_hash         => true,
  :ignore_query_string => false
}

rcfile = File.expand_path("~/.varnishrc")
if FileTest.readable? rcfile
  rc = YAML::load(File.open(rcfile))
  # Convert to symbols
  rc = rc.inject({}){ |memo,(k,v)| memo[k.to_sym] = v; memo }
  $options.merge!(rc)
end

optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: varnish.rb [options] action target'

  opts.on('-h', '--help', 'Display this help') do
    puts opts
  end

  opts.on('-v', '--verbose', 'Output more information') do
    $options[:verbose] = true
  end

  opts.on('-H', '--hostname HOSTNAME', 'Hostname/IP address of your Varnish server. Default is localhost') do |hostname|
    $options[:hostname] = hostname
  end

  opts.on('-p', '--port PORT', 'Port your Varnish server is listening on. Default is 80') do |port|
    $options[:port] = port
  end

  opts.on('-n', '--num-pages NUM', 'Number of pages to crawl when in spider mode. -1 will crawl all pages') do |num|
    $options[:num_pages] = num.to_i
  end

  opts.on('-#', '--hashes', 'If true, /foo.html#foo and /foo.html#bar will be seen as different in spider mode') do
    $options[:ignore_hash] = false 
  end

  opts.on('-q', '--ignore-query-string', 'If true, /foo?foo=bar and /foo?foo=baz will be seen as the same in spider mode') do
    $options[:ignore_query_string] = true
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
      VarnishToolkit::PagePurger.new target
    end

    # If target is a hostname, assume we want to purge an entire domain.
    if target =~ /^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$/
      VarnishToolkit::DomainPurger.new target
    end
  
  when "spider"
    VarnishToolkit::Spider.new target

  when "reindex"
    VarnishToolkit::DomainPurger.new target
    VarnishToolkit::Spider.new target

  else
    puts "Invalid action."
end