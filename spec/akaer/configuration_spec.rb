# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Akaer::Configuration do
  describe "#initialize" do
    it "sets default arguments and rules" do
      config = Akaer::Configuration.new
      expect(config.interface).to eq("lo0")
      expect(config.addresses).to eq([])
      expect(config.start_address).to eq("10.0.0.1")
      expect(config.aliases).to eq(5)
      expect(config.add_command).to eq("sudo ifconfig @INTERFACE@ alias @ALIAS@")
      expect(config.remove_command).to eq("sudo ifconfig @INTERFACE@ -alias @ALIAS@")
      expect(config.log_file).to eq($stdout)
      expect(config.log_level).to eq(Logger::INFO)
    end
  end
end