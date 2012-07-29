# akaer 

[![Build Status](https://secure.travis-ci.org/ShogunPanda/akaer.png?branch=master)](http://travis-ci.org/ShogunPanda/akaer)
[![Dependency Status](https://gemnasium.com/ShogunPanda/akaer.png?travis)](https://gemnasium.com/ShogunPanda/akaer)

A small utility to add aliases to network interfaces.

http://github.com/ShogunPanda/akaer

## Description

Akaer is a small utility that adds and remove aliases to your network interfaces. This is useful in web development.

## Basic usage

1. Install the gem:

	`gem install akaer`

2. Run the application:

	`akaer`

**You're done!**

## Advanced usage

Just type `akaer --help` and you'll see all available options.

## Configuration

By defaults, Akaer uses a configuration file in `~/.akaer_config`, but you can change the path using the `--config` switch.

The file is a plain Ruby file with a single `config` object that supports the following directives.

* `interface`: The network interface to manage. `lo0` by default.
* `address`: A specific list of aliases to manage.
* `start-address`: The address to start sequential address. `10.0.0.1` by default. Not used if `addresses` is specified.
* `aliases`: The number of sequential addresses to add. 5 by default.
* `log_file`: The default log file. By default it logs to standard output.
* `log_level`: The default log level. Valid values are from 0 to 5 where 0 means "all messages".

## Remarks

Akaer is tightly coupled with the UNIX tools, so it won't work for Windows.

## Contributing to akaer

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (C) 2012 and above Shogun <[shogun_panda@me.com](mailto:shogun_panda@me.com)>.
Licensed under the MIT license, which can be found at [http://www.opensource.org/licenses/mit-license.php](http://www.opensource.org/licenses/mit-license.php).
