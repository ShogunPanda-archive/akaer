# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new("spec")

desc "Run all specs with rcov"
RSpec::Core::RakeTask.new("spec:coverage") do |t|
  t.rcov_opts =  %q[--exclude "spec"]
end