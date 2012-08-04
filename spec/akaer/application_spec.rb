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

  let(:log_file) { "/tmp/akaer-test-log-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:application){ Akaer::Application.instance({:log_file => log_file}, {}, {}, true) }
  let(:executable) { ::Pathname.new(::File.dirname((__FILE__))) + "../../bin/akaer" }
  let(:sample_config) { ::Pathname.new(::File.dirname((__FILE__))) + "../../config/akaer_config.sample" }
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
      file.write("config.port = ")
      file.close

      expect { Akaer::Application.new({:config => file.path, :log_file => log_file}) }.to raise_error(::SystemExit)
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

        application.get_logger.should_receive(:error).with("Cannot create the launch agent.")
        application.action_install
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not load an invalid agent" do
        class Akaer::Application
          def execute_command(command)
            command =~ /^launchctl/ ? raise(StandardError) : system(command)
          end
        end

        application.stub(:launch_agent_path).and_return(launch_agent_path)
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)

        application.get_logger.should_receive(:error).with("Cannot load the launch agent.")
        application.action_install
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end
    end

    it "should raise an exception if not running on OSX" do
      application.stub(:is_osx?).and_return(false)
      application.get_logger.should_receive(:fatal).with("Install akaer on autolaunch is only available on MacOSX.")
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
        application.get_logger.should_receive(:warn).at_least(1)
        application.action_uninstall
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not delete an invalid agent" do
        application.stub(:launch_agent_path).and_return("/invalid/agent")

        application.action_install
        application.get_logger.should_receive(:warn).at_least(1)
        application.action_uninstall
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end

      it "should not load delete invalid agent" do
        application.stub(:launch_agent_path).and_return("/invalid/agent")

        application.action_install
        application.stub(:execute_command).and_raise(StandardError)
        application.get_logger.should_receive(:warn).at_least(1)
        application.action_uninstall
        ::File.unlink(application.launch_agent_path) if ::File.exists?(application.launch_agent_path)
      end
    end

    it "should raise an exception if not running on OSX" do
      application.stub(:is_osx?).and_return(false)
      application.get_logger.should_receive(:fatal).with("Install akaer on autolaunch is only available on MacOSX.")
      expect(application.action_uninstall).to be_false
    end
  end
end