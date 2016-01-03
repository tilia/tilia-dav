tilia/dav
======

[![Build Status](https://travis-ci.org/tilia/tilia-dav.svg?branch=master)](https://travis-ci.org/tilia/tilia-dav)

**tilia/dav is a port of [sabre/dav](https://github.com/fruux/sabre-dav)**

SabreDAV is the most popular WebDAV framework for PHP. Use it to create WebDAV, CalDAV and CardDAV servers.

Full documentation can be found on the website:

http://sabre.io/


Installation
------------

Simply add tilia-dav to your Gemfile and bundle it up:

```ruby
  gem 'tilia-dav', '~> 3.1'
```


Changes to sabre/dav
--------------------

The hook `afterResponse` does not exist in this implementation.


Contributing
------------

See [Contributing](CONTRIBUTING.md)


License
-------

tilia-dav is licensed under the terms of the [three-clause BSD-license](LICENSE).
