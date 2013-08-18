# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "./lib/akaer/version"

Gem::Specification.new do |gem|
  gem.name = "akaer"
  gem.version = Akaer::Version::STRING
  gem.authors = ["Shogun"]
  gem.email = ["shogun@cowtech.it"]
  gem.homepage = "http://sw.cow.tc/akaer"
  gem.summary = %q{A small utility to add aliases to network interfaces.}
  gem.description = %q{A small utility to add aliases to network interfaces.}

  gem.rubyforge_project = "akaer"
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.required_ruby_version = ">= 1.9.3"

  gem.add_dependency("bovem", "~> 3.0.2")
  gem.add_dependency("mustache", "~> 0.99.4")
end
