# varnisher

[![Build Status](https://travis-ci.org/robmiller/varnisher.png?branch=master)](https://travis-ci.org/robmiller/varnisher)

Administering Varnish is generally a breeze, but sometimes you want to
do one of the few things that aren't painless out of the box. Hopefully,
that's where this toolbox comes in.

Varnisher lets you do things like:

* Purge a webpage and everything (e.g. images, JavaScript files, CSS
  files) referenced on that page
* Spider an entire domain — useful for priming a cache
* Purge an entire domain, including optionally re-spidering it
  afterwards to keep the cache warm

Full documentation is available [on
rdoc.info](http://rdoc.info/github/robmiller/varnisher).

## Installation

Varnisher can be installed using RubyGems:

	gem install varnisher

Varnisher requires Ruby 1.9.3 or above.

## Usage

	NAME
	varnisher

	SYNOPSIS
	varnisher (purge|spider) [options]+

	DESCRIPTION
	Varnisher is a set of tools for working with the Varnish HTTP cache.

	PARAMETERS
	--verbose, -v
		If given, Varnisher will be noisier about what it's up to.
	--hostname=hostname, -H (0 ~> hostname=localhost)
		The hostname/IP address of your Varnish server.
	--port=port, -p (0 ~> int(port=80))
		The port Varnish is listening on.
	--help, -h

	EXAMPLES
	varnisher purge http://example.com
	varnisher spider example.com
	varnisher purge --reindex example.com

If you find yourself typing certain parameters every time you use the
script, you can specify them in an RC file called `.varnishrc` in your
home directory. The file format is YAML and the default options are, if
you want to paste and override them:

    verbose: false
    hostname: localhost
    port: 80
    num-pages: -1
    ignore-hashes: true
    ignore-query-strings: false

## Examples

### Purging a page and all the resources on it

Quite often, it's necessary redevelop a page on a website in a way that
involves changes not only to the page but also to CSS files, images,
JavaScript files, etc. Purging pages in this instance can be a painful
process, or at least one that requires a few `ban` commands in
`varnishadm`. No longer!

Just enter:

	$ varnisher purge http://www.example.com/path/to/page

...and `/path/to/page`, along with all its images, CSS files, JavaScript
files, and other external accoutrements, will be purged from Varnish's
cache.

As a bonus, this action is multithreaded, meaning even resource-heavy
pages should purge quickly and evenly.

This action requires your VCL to have something like the following,
which is fairly standard:

	if (req.request == "PURGE") {
        if ( client.ip ~ auth ) {
            ban("obj.http.x-url == " + req.url + " && obj.http.x-host == " + req.http.host);
            error 200 "Purged.";
        }
    }

(For an explanation of just what `obj.http.x-url` means, and why you
should use it rather than `req.url`, see [this
page](http://kly.no/posts/2010_07_28__Smart_bans_with_Varnish__.html).)

### Purging an entire domain

Provided your VCL has something akin to the following in it:

	if ( req.request == "DOMAINPURGE" ) {
            if ( client.ip ~ auth ) {
                    ban("obj.http.x-host == " + req.http.host);
                    error 200 "Purged.";
            }
    }

...then you should be able to quickly purge an entire domain's worth of
pages and resources by simply issuing the command:

	$ varnisher purge www.example.com

### Repopulating the cache

If you've purged a whole domain, and particularly if your backend is
slow, you might want to quickly repopulate the cache so that users never
see your slow misses. Well, you can! Use the `spider` action:

	$ varnisher spider www.example.com

`spider` accepts either a hostname or a URL as its starting point, and
will only fetch pages on the same domain as its origin. You can limit
the number of pages it will process using the `-n` parameter:

	$ varnisher -n 500 spider www.example.com

If you'd like to combine purging and spidering, you can use the
`reindex` option:

	$ varnisher purge --reindex www.example.com

…which is functionally equivalent to:

	$ varnisher purge www.example.com
	$ varnisher spider www.example.com
