# Varnish Toolkit

Administering Varnish is generally a breeze, but sometimes you want to do one of the few things that aren't painless out of the box. Hopefully, that's where these scripts come in.

## purge.rb

Feed `purge.rb` a URL, and it'll purge it. However, it will also inspect the URL for external resources — images, JavaScript files, CSS files, etc. — and purge those, too. For those occasions when you push a large change to a website, and would prefer to take a lower hitrate than a potentially dodgy-looking site.

### How to use

#### Configuration

Either edit the script to change PROXY_HOSTNAME and PROXY_PORT to point to your Varnish server's external IP and port.

Then, call purge.rb with the URL of the page you'd like to purge:

		$ ./purge.rb http://www.example.com/some/page
