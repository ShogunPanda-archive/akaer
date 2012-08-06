# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Akaer::Application do
  before(:each) do
    Bovem::Logger.stub(:default_file).and_return("/dev/null")
  end

  let(:log_file) { "/dev/null" }
  let(:application){ Akaer::Application.instance({:"log-file" => log_file}, true) }
  let(:launch_agent_path) { "/tmp/akaer-test-agent-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }

  describe "#initialize" do
    it("should setup the logger") do
      expect(application.logger).not_to be_nil
    end

    it("should setup the configuration") do
      expect(application.config).not_to be_nil
    end

    it("should abort with an invalid configuration") do
      path = "/tmp/akaer-test-#{Time.now.strftime("%Y%m%d-%H:%M:%S")}"
      file = ::File.new(path, "w")
      file.write("config.aliases = ")
      file.close

      expect { Akaer::Application.new({:config => file.path, :"log-file" => log_file}) }.to raise_error(::SystemExit)
      ::File.unlink(path)
    end
  end

  describe "#launch_agent_path" do
    it "should return the agent file with a default name" do
      expect(application.launch_agent_path).to eq(ENV["HOME"] + "/Library/LaunchAgents/it.cowtech.akaer.plist")
    end

    it "should return the agent file with a specified name" do
      expect(application.launch_agent_path("foo")).to eq(ENV["HOME"] + "/Library/LaunchAgents/foo.plist")
    end
  end

  describe "#pad_number" do
    it "correctly pads numbers" do
      expect(application.pad_number(3)).to eq("03")
      expect(application.pad_number(300)).to eq("300")
      expect(application.pad_number(3, 3)).to eq("003")
      expect(application.pad_number(nil)).to eq("00")
      expect(application.pad_number(3, -3)).to eq("03")
      expect(application.pad_number(3, "A")).to eq("03")
    end
  end

  describe "#is_ipv4?" do
    it "correctly detects valid IPv4 address" do
      expect(application.is_ipv4?("10.0.0.1")).to be_true
      expect(application.is_ipv4?("255.0.0.1")).to be_true
      expect(application.is_ipv4?("192.168.0.1")).to be_true
    end

    it "rejects other values" do
      expect(application.is_ipv4?("10.0.0.256")).to be_false
      expect(application.is_ipv4?("10.0.0.-1")).to be_false
      expect(application.is_ipv4?("::1")).to be_false
      expect(application.is_ipv4?("INVALID")).to be_false
      expect(application.is_ipv4?(nil)).to be_false
    end
  end

  describe "#is_ipv6?" do
    it "correctly detects valid IPv4 address" do
      expect(application.is_ipv6?("2001:0db8:0000:0000:0000:1428:57ab")).to be_true
      expect(application.is_ipv6?("2001:0db8:0:000:00:1428:57ab")).to be_true
      expect(application.is_ipv6?("2001:0db8:0::1428:57ab")).to be_true
      expect(application.is_ipv6?("2001::")).to be_true
      expect(application.is_ipv6?("::1")).to be_true
      expect(application.is_ipv6?("::2:1")).to be_true
      expect(application.is_ipv6?("2011::10.0.0.1")).to be_true
      expect(application.is_ipv6?("2011::0:10.0.0.1")).to be_true
    end

    it "rejects other values" do
      expect(application.is_ipv6?("::H")).to be_false
      expect(application.is_ipv6?("192.168.0.256")).to be_false
      expect(application.is_ipv6?("INVALID")).to be_false
      expect(application.is_ipv6?(nil)).to be_false
    end
  end

  describe "#compute_addresses" do
    describe "should use only the explicit list if given" do
      let(:other_application){ Akaer::Application.new({:"log-file" => log_file, :addresses => ["10.0.0.1", "::1", "INVALID 1", "10.0.0.2", "INVALID 2", "2001:0db8:0::0:1428:57ab"]}) }

      it "considering all address" do
        expect(other_application.compute_addresses).to eq(["10.0.0.1", "::1", "10.0.0.2", "2001:0db8:0::0:1428:57ab"])
      end

      it "considering only IPv4" do
        expect(other_application.compute_addresses(:ipv4)).to eq(["10.0.0.1", "10.0.0.2"])
        expect(Akaer::Application.new({:"log-file" => log_file, :addresses => ["::1", "INVALID 1"]}).compute_addresses(:ipv4)).to eq([])
      end

      it "considering only IPv6" do
        expect(other_application.compute_addresses(:ipv6)).to eq(["::1", "2001:0db8:0::0:1428:57ab"])
        expect(Akaer::Application.new({:"log-file" => log_file, :addresses => ["10.0.0.1", "INVALID 1"]}).compute_addresses(:ipv6)).to eq([])
      end
    end

    describe "should compute a sequential list of address" do
      it "considering all address" do
        expect(Akaer::Application.new({:"log-file" => log_file, :"start-address" => "10.0.1.1"}).compute_addresses).to eq(["10.0.1.1", "10.0.1.2", "10.0.1.3", "10.0.1.4", "10.0.1.5"])
        expect(Akaer::Application.new({:"log-file" => log_file, :aliases => 3}).compute_addresses).to eq(["10.0.0.1", "10.0.0.2", "10.0.0.3"])
        expect(Akaer::Application.new({:"log-file" => log_file, :"start-address" => "10.0.1.1", :aliases => -1}).compute_addresses).to eq(["10.0.1.1", "10.0.1.2", "10.0.1.3", "10.0.1.4", "10.0.1.5"])
      end

      it "considering only IPv4" do
        expect(Akaer::Application.new({:"log-file" => log_file, :"start-address" => "::1"}).compute_addresses(:ipv4)).to eq([])
      end

      it "considering only IPv6" do
        expect(Akaer::Application.new({:"log-file" => log_file, :"start-address" => "10.0.0.1"}).compute_addresses(:ipv6)).to eq([])
      end
    end
  end

  describe "#execute_command" do
    it "should forward to system" do
      Kernel.should_receive("system")
      application.execute_command("echo OK")
    end
  end

  describe "#manage" do
    it "should show a right message to the user" do
      application.logger.should_receive(:info).with(/.+.*03.*\/.*05.*.+ *Adding.* address .*10.0.0.3.* to interface .*lo0.*/)
      application.manage(:add, "10.0.0.3")

      application.logger.should_receive(:info).with(/.+.*03.*\/.*05.*.+ *Removing.* address .*10.0.0.3.* from interface .*lo0.*/)
      application.manage(:remove, "10.0.0.3")
    end

    it "should call the right system command" do
      application.should_receive(:execute_command).with("sudo ifconfig lo0 alias 10.0.0.3 > /dev/null 2>&1")
      application.manage(:add, "10.0.0.3")

      application.should_receive(:execute_command).with("sudo ifconfig lo0 -alias 10.0.0.3 > /dev/null 2>&1")
      application.manage(:remove, "10.0.0.3")
    end

    it "should return true if the command succeded" do
      other_application = Akaer::Application.new({:"add-command" => "echo @INTERFACE@", :quiet => true})
      expect(other_application.manage(:add, "10.0.0.3")).to be_true
    end

    it "should return false if the command failed" do
      expect(other_application.manage(:add, "10.0.0.256")).to be_false
    end

    it "should respect dry-run mode" do
      other_application = Akaer::Application.new({:"log-file" => log_file, :"dry-run" => true})

      other_application.logger.should_receive(:info).with(/.+.*03.*\/.*05.*.+ I will .*add.* address .*10.0.0.3.* to interface .*lo0.*/)
      other_application.should_not_receive(:execute_command)
      other_application.manage(:add, "10.0.0.3")

      other_application.logger.should_receive(:info).with(/.+.*03.*\/.*05.*.+ I will .*remove.* address .*10.0.0.3.* from interface .*lo0.*/)
      other_application.should_not_receive(:execute_command)
      other_application.manage(:remove, "10.0.0.3")
    end
  end


  describe "#action_add" do
    it("should compute addresses to manage") do
      application.should_receive(:compute_addresses)
      application.action_add
    end

    it("should call #manage for every command") do
      application.stub(:manage) do |operation, address|
        address !~ /3$/
      end

      application.should_receive(:manage).at_most(application.compute_addresses.length).with(:add, /.+/)
      application.action_add
    end

    it("should show an error there's no address to manage") do
      application.stub(:compute_addresses).and_return([])
      other_application = Akaer::Application.new({:"log-file" => log_file, :quiet => true})
      other_application.stub(:compute_addresses).and_return([])

      application.logger.should_receive(:error).with("No valid addresses to add to the interface found.")
      application.action_add
      other_application.logger.should_not_receive(:error)
      other_application.action_add
    end
  end

  describe "#action_remove" do
    it("should compute addresses to manage") do
      application.should_receive(:compute_addresses)
      application.action_remove
    end

    it("should call #manage for every command") do
      application.stub(:manage) do |operation, address|
        address !~ /3$/
      end

      application.should_receive(:manage).at_most(application.compute_addresses.length).with(:remove, /.+/)
      application.action_remove
    end

    it("should show an error there's no address to manage") do
      application.stub(:compute_addresses).and_return([])
      other_application = Akaer::Application.new({:"log-file" => log_file, :quiet => true})
      other_application.stub(:compute_addresses).and_return([])

      application.logger.should_receive(:error).with("No valid addresses to remove from the interface found.")
      application.action_remove
      other_application.logger.should_not_receive(:error)
      other_application.action_remove
    end
  end

  describe "#action_install" do
    if ::Config::CONFIG['host_os'] =~ /^darwin/ then
      it "should create the agent" do
        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.action_install
        expect(::File.exists?(application.launch_agent_path)).to be_true
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not create and invalid agent" do
        application.stub(:launch_agent_path).and_return("/invalid/agent")
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.logger.should_receive(:error).with("Cannot create the launch agent.")
        application.action_install
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not load an invalid agent" do
        application.stub(:execute_command) do |command|
          command =~ /^launchctl/ ? raise(StandardError) : system(command)
        end

        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.logger.should_receive(:error).with("Cannot load the launch agent.")
        application.action_install
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end
    end

    it "should raise an exception if not running on OSX" do
      application.stub(:is_osx?).and_return(false)
      application.logger.should_receive(:fatal).with("Install akaer on autolaunch is only available on MacOSX.")
      expect(application.action_install).to be_false
    end
  end

  describe "#action_uninstall" do
    if ::Config::CONFIG['host_os'] =~ /^darwin/ then
      it "should remove the agent" do
        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        Bovem::Logger.stub(:default_file).and_return($stdout)
        application.action_install
        application.action_uninstall
        expect(::File.exists?(application.launch_agent_path)).to be_false
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not load delete an invalid resolver" do
        application.stub(:launch_agent_path).and_return("/invalid/agent")

        application.action_install
        application.logger.should_receive(:warn).at_least(1)
        application.action_uninstall
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not delete an invalid agent" do
        application.stub(:launch_agent_path).and_return("/invalid/agent")

        application.action_install
        application.logger.should_receive(:warn).at_least(1)
        application.action_uninstall
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not load delete invalid agent" do
        application.stub(:launch_agent_path).and_return("/invalid/agent")

        application.action_install
        application.stub(:execute_command).and_raise(StandardError)
        application.logger.should_receive(:warn).at_least(1)
        application.action_uninstall
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end
    end

    it "should raise an exception if not running on OSX" do
      application.stub(:is_osx?).and_return(false)
      application.logger.should_receive(:fatal).with("Install akaer on autolaunch is only available on MacOSX.")
      expect(application.action_uninstall).to be_false
    end
  end
end