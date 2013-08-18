# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Akaer::Application do
  def create_application(overrides)
    mamertes_app = Bovem::Application.create(run: false) do
      option :configuration, [], {type: String, default: overrides["configuration"] || "/dev/null"}
      option :interface, [], {type: String, default: overrides["interface"] || "lo0"}
      option :addresses, [], {type: Array, default: overrides["addresses"] || []}
      option :start_address, [], {type: String, default: overrides["start-address"] || "10.0.0.1"}
      option :aliases, [:S], {type: Integer, default: overrides["aliases"] || 5}
      option :add_command, [:A], {type: String, default: overrides["add-command"] || "sudo ifconfig {{interface}} alias {{address}}"}
      option :remove_command, [:R], {type: String, default: overrides["remove-command"] || "sudo ifconfig {{interface}} -alias {{address}}"}
      option :log_file, [], {type: String, default: overrides["log-file"] || "/dev/null"}
      option :log_level, [:L], {type: Integer, default: overrides["log-level"] || 1}
      option :dry_run, [:n], {default: overrides["dry-run"] || false}
      option :quiet, [], {default: overrides["quiet"] || false}
    end

    ::Akaer::Application.new(mamertes_app, :en)
  end

  before(:each) do
    allow(Bovem::Logger).to receive(:default_file).and_return("/dev/null")
  end
  let(:log_file) { "/dev/null" }
  let(:application){ create_application({"log-file" => log_file}) }
  let(:launch_agent_path) { "/tmp/akaer-test-agent-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }

  describe ".instance" do
    it "should call .new with the passed arguments" do
      expect(::Akaer::Application).to receive(:new).with("FOO", :es)
      ::Akaer::Application.instance("FOO", :es)
    end

    it "should return the same instance" do
      allow(::Akaer::Application).to receive(:new) { Time.now }
      instance = ::Akaer::Application.instance("start")
      expect(::Akaer::Application.instance("stop")).to be(instance)
    end

    it "should return a new instance if requested to" do
      allow(::Akaer::Application).to receive(:new) { Time.now }
      instance = ::Akaer::Application.instance("")
      expect(::Akaer::Application.instance({"log-file" => "/dev/null"}, nil, true)).not_to be(instance)
    end
  end

  describe "#initialize" do
    it "should setup the logger" do
      expect(application.logger).not_to be_nil
    end

    it "should setup the configuration" do
      expect(application.config).not_to be_nil
    end

    it "should abort with an invalid configuration" do
      path = "/tmp/akaer-test-#{Time.now.strftime("%Y%m%d-%H:%M:%S")}"
      file = ::File.new(path, "w")
      file.write("config.aliases = ")
      file.close

      expect { create_application({"configuration" => file.path, "log-file" => log_file}) }.to raise_error(::SystemExit)
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
      let(:other_application){ create_application({"log-file" => log_file, "addresses" => ["10.0.0.1", "::1", "INVALID 1", "10.0.0.2", "INVALID 2", "2001:0db8:0::0:1428:57ab"]}) }

      it "considering all address" do
        expect(other_application.compute_addresses).to eq(["10.0.0.1", "::1", "10.0.0.2", "2001:0db8:0::0:1428:57ab"])
      end

      it "considering only IPv4" do
        expect(other_application.compute_addresses(:ipv4)).to eq(["10.0.0.1", "10.0.0.2"])
        expect(create_application({"log-file" => log_file, "addresses" => ["::1", "INVALID 1"]}).compute_addresses(:ipv4)).to eq([])
      end

      it "considering only IPv6" do
        expect(other_application.compute_addresses(:ipv6)).to eq(["::1", "2001:0db8:0::0:1428:57ab"])
        expect(create_application({"log-file" => log_file, "addresses" => ["10.0.0.1", "INVALID 1"]}).compute_addresses(:ipv6)).to eq([])
      end
    end

    describe "should compute a sequential list of address" do
      it "considering all address" do
        expect(create_application({"log-file" => log_file, "start-address" => "10.0.1.1"}).compute_addresses).to eq(["10.0.1.1", "10.0.1.2", "10.0.1.3", "10.0.1.4", "10.0.1.5"])
        expect(create_application({"log-file" => log_file, "aliases" => 3}).compute_addresses).to eq(["10.0.0.1", "10.0.0.2", "10.0.0.3"])
        expect(create_application({"log-file" => log_file, "start-address" => "10.0.1.1", aliases: -1}).compute_addresses).to eq(["10.0.1.1", "10.0.1.2", "10.0.1.3", "10.0.1.4", "10.0.1.5"])
      end

      it "considering only IPv4" do
        expect(create_application({"log-file" => log_file, "start-address" => "::1"}).compute_addresses(:ipv4)).to eq([])
      end

      it "considering only IPv6" do
        expect(create_application({"log-file" => log_file, "start-address" => "10.0.0.1"}).compute_addresses(:ipv6)).to eq([])
      end
    end
  end

  describe "#execute_command" do
    it "should forward to system" do
      expect(Kernel).to receive("system")
      application.execute_command("echo OK")
    end
  end

  describe "#is_osx?" do
    it "should return the correct information" do
      stub_const("RbConfig::CONFIG", {"host_os" => "darwin foo"})
      expect(application.is_osx?).to be_true
      stub_const("RbConfig::CONFIG", {"host_os" => "another"})
      expect(application.is_osx?).to be_false
    end
  end

  describe "#manage" do
    it "should show a right message to the user" do
      expect(application.logger).to receive(:info).with(/.+.*03.*\/.*05.*.+ *Adding.* address .*10.0.0.3.* to interface .*lo0.*/)
      application.manage(:add, "10.0.0.3")

      expect(application.logger).to receive(:info).with(/.+.*03.*\/.*05.*.+ *Removing.* address .*10.0.0.3.* from interface .*lo0.*/)
      application.manage(:remove, "10.0.0.3")
    end

    it "should call the right system command" do
      expect(application).to receive(:execute_command).with("sudo ifconfig lo0 alias 10.0.0.3 > /dev/null 2>&1")
      application.manage(:add, "10.0.0.3")

      expect(application).to receive(:execute_command).with("sudo ifconfig lo0 -alias 10.0.0.3 > /dev/null 2>&1")
      application.manage(:remove, "10.0.0.3")
    end

    it "should return true if the command succeded" do
      other_application = create_application({"add-command" => "echo {{interface}}", "quiet" => true})
      expect(other_application.manage(:add, "10.0.0.3")).to be_true
    end

    it "should return false if the command failed" do
      expect(application.manage(:add, "10.0.0.256")).to be_false
    end

    it "should respect dry-run mode" do
      other_application = create_application({"log-file" => log_file, "dry-run" => true})

      expect(other_application.logger).to receive(:info).with(/.+.*03.*\/.*05.*.+ I will .*add.* address .*10.0.0.3.* to interface .*lo0.*/)
      expect(other_application).not_to receive(:execute_command)
      other_application.manage(:add, "10.0.0.3")

      expect(other_application.logger).to receive(:info).with(/.+.*03.*\/.*05.*.+ I will .*remove.* address .*10.0.0.3.* from interface .*lo0.*/)
      expect(other_application).not_to receive(:execute_command)
      other_application.manage(:remove, "10.0.0.3")
    end
  end

  describe "#action_add" do
    it "should compute addresses to manage" do
      expect(application).to receive(:compute_addresses)
      application.action_add
    end

    it "should call #manage for every command" do
      allow(application).to receive(:manage) do |operation, address|
        address !~ /3$/
      end

      expect(application).to receive(:manage).at_most(application.compute_addresses.length).with(:add, /.+/)
      application.action_add
    end

    it "should show an error there's no address to manage" do
      allow(application).to receive(:compute_addresses).and_return([])
      other_application = create_application({"log-file" => log_file, "quiet" => true})
      allow(other_application).to receive(:compute_addresses).and_return([])

      expect(application.logger).to receive(:error).with("No valid addresses to add to the interface found.")
      application.action_add
      expect(other_application.logger).not_to receive(:error)
      other_application.action_add
    end
  end

  describe "#action_remove" do
    it "should compute addresses to manage" do
      expect(application).to receive(:compute_addresses)
      application.action_remove
    end

    it "should call #manage for every command" do
      allow(application).to receive(:manage) do |operation, address|
        address !~ /3$/
      end

      expect(application).to receive(:manage).at_most(application.compute_addresses.length).with(:remove, /.+/)
      application.action_remove
    end

    it "should show an error there's no address to manage" do
      allow(application).to receive(:compute_addresses).and_return([])
      other_application = create_application({"log-file" => log_file, "quiet" => true})
      allow(other_application).to receive(:compute_addresses).and_return([])

      expect(application.logger).to receive(:error).with("No valid addresses to remove from the interface found.")
      application.action_remove
      expect(other_application.logger).not_to receive(:error)
      other_application.action_remove
    end
  end

  describe "#action_install" do
    before(:each) do
      allow(application).to receive(:is_osx?).and_return(true)
      allow(application).to receive(:execute_command)
    end

    it "should create the agent" do
      allow(application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      application.action_install
      expect(::File.exists?(application.launch_agent_path)).to be_true
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not create and invalid agent" do
      allow(application).to receive(:launch_agent_path).and_return("/invalid/agent")

      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      expect(application.logger).to receive(:error).with("Cannot create the launch agent.")
      application.action_install
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not load an invalid agent" do
      allow(application).to receive(:execute_command) do |command|
        command =~ /^launchctl/ ? raise(StandardError) : true
      end

      allow(application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      expect(application.logger).to receive(:error).with("Cannot load the launch agent.")
      application.action_install
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should raise an exception if not running on OSX" do
      allow(application).to receive(:is_osx?).and_return(false)
      expect(application.logger).to receive(:fatal).with("Installing akaer on autolaunch is only available on MacOSX.")
      expect(application.action_install).to be_false
    end
  end

  describe "#action_uninstall" do
    before(:each) do
      allow(application).to receive(:is_osx?).and_return(true)
      allow(application).to receive(:execute_command)
    end

    it "should remove the agent" do
      allow(application).to receive(:launch_agent_path).and_return(launch_agent_path)
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

      allow(Bovem::Logger).to receive(:default_file).and_return($stdout)
      application.action_install
      application.action_uninstall
      expect(::File.exists?(application.launch_agent_path)).to be_false
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not load delete an invalid resolver" do
      allow(application).to receive(:launch_agent_path).and_return("/invalid/agent")

      application.action_install
      expect(application.logger).to receive(:warn).at_least(1)
      application.action_uninstall
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not delete an invalid agent" do
      allow(application).to receive(:launch_agent_path).and_return("/invalid/agent")

      application.action_install
      expect(application.logger).to receive(:warn).at_least(1)
      application.action_uninstall
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should not load delete invalid agent" do
      allow(application).to receive(:launch_agent_path).and_return("/invalid/agent")

      application.action_install
      allow(application).to receive(:execute_command).and_raise(StandardError)
      expect(application.logger).to receive(:warn).at_least(1)
      application.action_uninstall
      ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
    end

    it "should raise an exception if not running on OSX" do
      allow(application).to receive(:is_osx?).and_return(false)
      expect(application.logger).to receive(:fatal).with("Installing akaer on autolaunch is only available on MacOSX.")
      expect(application.action_uninstall).to be_false
    end
  end
end
