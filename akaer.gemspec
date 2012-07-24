# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "./lib/akaer/version"

Gem::Specification.new do |gem|
  gem.name = "akaer"
  gem.version = Akaer::Version::STRING
  gem.authors = ["Shogun"]
  gem.email = ["shogun_panda@me.com"]
  gem.homepage = "http://github.com/ShogunPanda/akaer"
  gem.summary = %q{A small utility to add aliases to network interfaces.}
  gem.description = %q{A small utility to add aliases to network interfaces.}

  gem.rubyforge_project = "akaer"
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.add_dependency("cowtech-extensions", "~> 2.5.0")
  gem.add_dependency("cowtech-lib", "~> 1.9.8.0")
  gem.add_dependency("hashie", "~> 1.2.0")
  gem.add_dependency("rainbow", "~> 1.1.0")

  gem.add_development_dependency("rspec", "~> 2.11.0")
  gem.add_development_dependency("rcov", "~> 1.0.0")
  gem.add_development_dependency("pry", "~> 0.9.9")
end


