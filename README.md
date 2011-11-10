# Varnish Toolkit

Administering Varnish is generally a breeze, but sometimes you want to do one of the few things that aren't painless out of the box. Hopefully, that's where this toolbox comes in.

## Usage

	Usage: varnish.rb [options] action target
    -h, --help                       Display this help
    -v, --verbose                    Output more information
    -H, --hostname HOSTNAME          Hostname/IP address of your Varnish server
    -p, --port PORT                  Port your Varnish server is listening on

## Examples

### Purging a page and all the resources on it

Quite often, it's necessary redevelop a page on a website in a way that involves changes not only to the page but also to CSS files, images, JavaScript files, etc. Purging pages in this instance can be a painful process, or at least one that requires a few `ban` commands in `varnishadm`. No longer!

Just enter:

	$ varnish.rb purge http://www.example.com/path/to/page

...and `/path/to/page`, along with all its images, CSS files, JavaScript files, and other external accoutrements, will be purged from Varnish's cache. 

As a bonus, this action is multithreaded, meaning even resource-heavy pages should purge quickly and evenly.

This action requires your VCL to have something like the following, which is fairly standard:

	if (req.request == "PURGE") {
        if ( client.ip ~ auth ) {
            ban("obj.http.x-url == " + req.url + " && obj.http.x-host == " + req.http.host);
            error 200 "Purged.";
        }
    }

(For an explanation of just what `obj.http.x-url` means, and why you should use it rather than `req.url`, see [this page](http://kristianlyng.wordpress.com/2010/07/28/smart-bans-with-varnish/).)

### Purging an entire domain

Provided your VCL has something akin to the following in it:

	if ( req.request == "DOMAINPURGE" ) {
            if ( client.ip ~ auth ) {
                    ban("obj.http.x-host == " + req.http.host);
                    error 200 "Purged.";
            }
    }

...then you should be able to quickly purge an entire domain's worth of pages and resources by simply issuing the command:

	$ varnish.rb purge www.example.com