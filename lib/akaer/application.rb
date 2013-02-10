# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A small utility to add aliases to network interfaces.
module Akaer
  # Methods for the {Application Application} class.
  module ApplicationMethods
    # General methods.
    module General
      extend ActiveSupport::Concern

      # Checks if we are running on MacOS X.
      #
      # System services are only available on that platform.
      #
      # @return [Boolean] `true` if the current platform is MacOS X, `false` otherwise.
      def is_osx?
        ::RbConfig::CONFIG['host_os'] =~ /^darwin/
      end

      # Adds or removes an alias from the interface.
      #
      # @param type [Symbol] The operation to execute. Can be `:add` or `:remove`.
      # @param address [String] The address to manage.
      # @return [Boolean] `true` if operation succedeed, `false` otherwise.
      def manage(type, address)
        locale = self.i18n
        config = self.config
        quiet = config.quiet
        rv, command, prefix = setup_management(type, address)

        # Now execute
        if rv then
          if !config.dry_run then
            execute_manage(command, prefix, type, address, config, quiet)
          else
            log_management(:dry_run, prefix, type, locale.remove, locale.add, address, config, quiet)
          end
        end

        rv
      end

      private
        # Setups management.
        #
        # @param type [Symbol] The type of operation. Can be `:add` or `:remove`.
        # @param address [String] The address to manage.
        # @return [Array] A list of parameters for the management.
        def setup_management(type, address)
          begin
            @addresses ||= self.compute_addresses
            length = self.pad_number(@addresses.length)
            [true, Mustache.render(config.send((type == :remove) ? :remove_command : :add_command), {interface: config.interface, alias: address}) + " > /dev/null 2>&1", "{mark=blue}[{mark=bright white}#{self.pad_number((@addresses.index(address) || 0) + 1, length.length)}{mark=reset blue}/{/mark}#{length}{/mark}]{/mark}"]
          rescue ArgumentError
            [false]
          end
        end

        # Executes management.
        #
        # @param command [String] The command to execute.
        # @param prefix [String] The prefix to apply to the message.
        # @param type [Symbol] The type of operation. Can be `:add` or `:remove`.
        # @param address [String] The address that will be managed.
        # @param config [Configuration] The current configuration.
        # @param quiet [Boolean] Whether to show the message.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def execute_manage(command, prefix, type, address, config, quiet)
          locale = self.i18n
          log_management(:run, prefix, type, locale.removing, locale.adding, address, config, quiet)
          rv = self.execute_command(command)
          labels = (type == :remove ? [locale.remove, locale.from] : [locale.add, locale.to])
          @logger.error(@command.application.console.replace_markers(locale.general_error(labels[0], address, labels[1], config.interface))) if !rv
          rv
        end

        # Logs an operation.
        #
        # @param message [Symbol] The message to print.
        # @param prefix [String] The prefix to apply to the message.
        # @param type [Symbol] The type of operation. Can be `:add` or `:remove`.
        # @param remove_label [String] The label to use for removing.
        # @param add_label [String] The label to use for adding.
        # @param address [String] The address that will be managed.
        # @param config [Configuration] The current configuration.
        # @param quiet [Boolean] Whether to show the message.
        def log_management(message, prefix, type, remove_label, add_label, address, config, quiet)
          labels = (type == :remove ? [remove_label, locale.from] : [add_label, locale.to])
          @logger.info(@command.application.console.replace_markers(self.i18n.send(message, prefix, labels[0], address, labels[1], config.interface))) if !quiet
        end

        # Manages an action on the request addresses.
        #
        # @param operation [Symbol] The type of operation. Can be `:add` or `:remove`.
        # @param message [String] The message to show if no addresses are found.
        # @param quiet [Boolean] Whether to show the failure message.
        def manage_action(operation, message, quiet)
          addresses = self.compute_addresses

          if addresses.present? then
            # Now, for every address, call the command
            addresses.all? {|address|
              self.manage(operation, address)
            }
          else
            @logger.error(message) if !quiet
          end
        end
    end

    # System management methods.
    module System
      # Adds aliases to the interface.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_add
        manage_action(:add, self.i18n.add_empty, self.config.quiet)
      end

      # Removes aliases from the interface.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_remove
        manage_action(:remove, self.i18n.remove_empty, self.config.quiet)
      end

      # Installs the application into the autolaunch.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_install
        manage_agent(self.launch_agent_path, :create_agent, :load_agent, self.config.quiet)
      end

      # Uninstalls the application from the autolaunch.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_uninstall
        manage_agent(self.launch_agent_path, :unload_agent, :delete_agent, self.config.quiet)
      end

      private
        # Manages a OSX agent.
        #
        # @param launch_agent [String] The agent path.
        # @param first_operation [Symbol] The first operation to execute.
        # @param second_operation [Symbol] The second operation to execute.
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def manage_agent(launch_agent, first_operation, second_operation, quiet)
          rv = true

          rv = check_agent_available(quiet)
          rv = send(first_operation, launch_agent, quiet) if rv
          rv = send(second_operation, launch_agent, quiet) if rv
          rv
        end

        # Checks if agent is enabled (that is, we are on OSX).
        #
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if the agent is enabled, `false` otherwise.
        def check_agent_available(quiet)
          rv = true
          if !self.is_osx? then
            logger.fatal(self.i18n.no_agent) if !quiet
            rv = false
          end

          rv
        end

        # Creates a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def create_agent(launch_agent, quiet)
          begin
            self.logger.info(self.i18n.agent_creating(launch_agent)) if !quiet
            write_agent(launch_agent)
            self.execute_command("plutil -convert binary1 \"#{launch_agent}\"")
            true
          rescue
            self.logger.error(self.i18n.agent_creating_error) if !quiet
            false
          end
        end

        # Writes a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        def write_agent(launch_agent)
          ::File.open(launch_agent, "w") {|f|
            f.write({"KeepAlive" => false, "Label" => "it.cowtech.akaer", "Program" => (::Pathname.new(Dir.pwd) + $0).to_s, "ProgramArguments" => ($ARGV ? $ARGV[0, $ARGV.length - 1] : []), "RunAtLoad" => true}.to_json)
            f.flush
          }
        end

        # Deletes a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def delete_agent(launch_agent, quiet)
          begin
            self.logger.info(self.i18n.agent_deleting(launch_agent)) if !quiet
            ::File.delete(launch_agent)
          rescue => e
            self.logger.warn(self.i18n.agent_deleting_error) if !quiet
            return false
          end
        end

        # Loads a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def load_agent(launch_agent, quiet)
          begin
            perform_agent_loading(launch_agent, "load", :agent_loading, quiet)
          rescue
            self.logger.error(self.i18n.agent_loading_error) if !quiet
            false
          end
        end

        # Unloads a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def unload_agent(launch_agent, quiet)
          begin
            perform_agent_loading(launch_agent, "unload", :agent_unloading, quiet)
          rescue => e
            self.logger.warn(self.i18n.agent_unloading_error) if !quiet
            false
          end
        end

        # Performs operatoin on a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param command [String] The command to run.
        # @param message [String] The message to show.
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def perform_agent_loading(launch_agent, command, message, quiet)
          self.logger.info(self.i18n.send(message, launch_agent)) if !quiet
          self.execute_command("launchctl #{command} -w \"#{launch_agent}\" > /dev/null 2>&1")
          true
        end
    end
  end

  # The main Akaer application.
  #
  # @attribute config
  #   @return [Configuration] The {Configuration Configuration} of this application.
  # @attribute command
  #   @return [Mamertes::Command] The Mamertes command.
  # @attribute
  #   @return [Bovem::Logger] logger The logger for this application.
  class Application
    attr_reader :config
    attr_reader :command
    attr_accessor :logger

    include Lazier::I18n
    include Akaer::ApplicationMethods::General
    include Akaer::ApplicationMethods::System

    # Creates a new application.
    #
    # @param command [Mamertes::Command] The current Mamertes command.
    # @param locale [Symbol] The locale to use for the application.
    def initialize(command, locale)
      self.i18n_setup(:akaer, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"))
      self.i18n = locale

      @command = command
      options = @command.application.get_options.reject {|k,v| v.nil? }

      # Setup logger
      Bovem::Logger.start_time = Time.now
      @logger = Bovem::Logger.create(Bovem::Logger.get_real_file(options["log_file"]) || Bovem::Logger.default_file, Logger::INFO)

      # Open configuration
      read_configuration(options)

      self
    end

    # Checks if and address is a valid IPv4 address.
    #
    # @param address [String] The address to check.
    # @return [Boolean] `true` if the address is a valid IPv4 address, `false` otherwise.
    def is_ipv4?(address)
      address = address.ensure_string

      mo = /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\Z/.match(address)
      rv = (mo && mo.captures.all? {|i| i.to_i < 256}) ? true : false
    end

    # Checks if and address is a valid IPv6 address.
    #
    # @param address [String] The address to check.
    # @return [Boolean] `true` if the address is a valid IPv6 address, `false` otherwise.
    def is_ipv6?(address)
      address = address.ensure_string

      rv = catch(:valid) do
        # IPv6 (normal)
        throw(:valid, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*\Z/ =~ address
        throw(:valid, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*)?\Z/ =~ address
        throw(:valid, true) if /\A::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*)?\Z/ =~ address
        # IPv6 (IPv4 compat)
        throw(:valid, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:/ =~ address && self.is_ipv4?($')
        throw(:valid, true) if /\A[\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:)?/ =~ address && self.is_ipv4?($')
        throw(:valid, true) if /\A::([\dA-Fa-f]{1,4}(:[\dA-Fa-f]{1,4})*:)?/ =~ address && self.is_ipv4?($')

        false
      end
    end


    # Pads a number to make it print friendly.
    #
    # @param num [Fixnum] The number to pad.
    # @param len [Fixnum] The minimum length of the padded string.
    # @return [String] The padded number.
    def pad_number(num, len = nil)
      num.to_integer.to_s.rjust([len.to_integer, 2].max, "0")
    end

    # Gets the current logger of the application.
    #
    # @return [Logger] The current logger of the application.
    def get_logger
      @logger ||= Bovem::Logger.create(@config.log_file, @config.log_level, @log_formatter)
    end

    # Gets the path for the launch agent file.
    #
    # @param name [String] The base name for the agent.
    # @return [String] The path for the launch agent file.
    def launch_agent_path(name = "it.cowtech.akaer")
      ENV["HOME"] + "/Library/LaunchAgents/#{name}.plist"
    end

    # Executes a shell command.
    #
    # @param command [String] The command to execute.
    # @return [Boolean] `true` if command succeeded, `false` otherwise.
    def execute_command(command)
      Kernel.system(command)
    end

    # Computes the list of address to manage.
    #
    # @param type [Symbol] The type of addresses to consider. Valid values are `:ipv4`, `:ipv6`, otherwise all addresses are considered.
    # @return [Array] The list of addresses to add or remove from the interface.
    def compute_addresses(type = :all)
      config = self.config
      config.addresses.present? ? filter_addresses(config, type) : generate_addresses(config, type)
    end

    # Returns a unique (singleton) instance of the application.
    #
    # @param command [Mamertes::Command] The current Mamertes command.
    # @param locale [Symbol] The locale to use for the application.
    # @param force [Boolean] If to force recreation of the instance.
    # @return [Application] The unique (singleton) instance of the application.
    def self.instance(command, locale = nil, force = false)
      @instance = nil if force
      @instance ||= Akaer::Application.new(command, locale)
    end

    private
      # Reads the configuration.
      #
      # @param options [Hash] The options to read.
      def read_configuration(options)
        begin
          @config = Akaer::Configuration.new(options["configuration"], options, @logger)
          @logger = nil
          @logger = self.get_logger
        rescue Bovem::Errors::InvalidConfiguration => e
          @logger ? @logger.fatal(e.message) : Bovem::Logger.create("STDERR").fatal(self.i18n.logging_failed(log_file))
          raise ::SystemExit
        end
      end

      # Filters a list of addresses to return just certain type(s).
      #
      # @param config [Configuration] The current configuration.
      # @param type [Symbol] The type of addresses to return.
      # @return [Array] A list of IPs.
      def filter_addresses(config, type)
        filters =  [:ipv4, :ipv6].select {|i| type == i || type == :all }.compact

        rv = config.addresses.select { |address|
          filters.any? {|filter| self.send("is_#{filter}?", address) }
        }.compact.uniq
      end

      # Generates a list of addresses which are immediate successors of a start address.
      #
      # @param config [Configuration] The current configuration.
      # @param type [Symbol] The type of addresses to return.
      # @return [Array] A list of IPs.
      def generate_addresses(config, type)
        begin
          ip = IPAddr.new(config.start_address.ensure_string)
          raise ArgumentError if type != :all && !ip.send("#{type}?")

          (config.aliases > 0 ? config.aliases : 5).times.collect {|i|
            current = ip
            ip = ip.succ
            current
          }
        rescue ArgumentError
          []
        end
      end
  end
end