# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "rubygems"
require "bundler/setup"
require "akaer"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end