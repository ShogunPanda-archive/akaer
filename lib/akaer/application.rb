# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A small utility to add aliases to network interfaces.
module Akaer
  # The main Akaer application.
  #
  # @attribute config
  #   @return [Configuration] The {Configuration Configuration} of this application.
  # @attribute command
  #   @return [Mamertes::Command] The Mamertes command.
  # @attribute
  #   @return [Bovem::Logger] logger The logger for this application.

  # Methods for the {Application Application} class.
  module ApplicationMethods
    # System management methods.
    module System
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
        config = self.config
        quiet = config.quiet
        rv, command, prefix = setup_management(type, address)

        # Now execute
        if rv then
          if !config.dry_run then
            log_management(prefix, type, "Removing", "Adding", address, config, quiet)
            rv = self.execute_command(command)
            @logger.error(@command.application.console.replace_markers("Cannot {mark=bright}#{(type == :remove ? "remove" : "add")}{/mark} address {mark=bright}#{address}{/mark} #{type != :remove ? "to" : "from"} interface {mark=bright}#{config.interface}{/mark}.")) if !rv
          else
            log_management(prefix, type, "remove", "add", address, config, quiet)
          end
        end

        rv
      end

      # Adds aliases to the interface.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_add
        manage_action(:add, "No valid addresses to add to the interface found.", self.config.quiet)
      end

      # Removes aliases from the interface.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_remove
        manage_action(:remove, "No valid addresses to remove from the interface found.", self.config.quiet)
      end

      # Installs the application into the autolaunch.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_install
        rv = true
        launch_agent = self.launch_agent_path
        quiet = self.config.quiet

        rv = check_agent_available(quiet)
        rv = create_agent(launch_agent, quiet) if rv
        rv = load_agent(launch_agent, quiet) if rv
        rv
      end

      # Uninstalls the application from the autolaunch.
      #
      # @return [Boolean] `true` if action succedeed, `false` otherwise.
      def action_uninstall
        rv = true
        launch_agent = self.launch_agent_path
        quiet = self.config.quiet

        rv = check_agent_available(quiet)
        rv = unload_agent(launch_agent, quiet) if rv
        rv = delete_agent(launch_agent, quiet) if rv
        rv
      end

      private
        # Setup management.
        #
        # @param type [Symbol] The type of operation. Can be `:add` or `:remove`.
        # @param address [String] The address to manage.
        # @return [Array] A list of parameters for the management.
        def setup_management(type, address)
          begin
            @addresses ||= self.compute_addresses
            length = self.pad_number(@addresses.length)
            [true, config.send((type == :remove) ? :remove_command : :add_command).gsub("@INTERFACE@", config.interface).gsub("@ALIAS@", address) + " > /dev/null 2>&1", "{mark=blue}[{mark=bright white}#{self.pad_number((@addresses.index(address) || 0) + 1, length.length)}{mark=reset blue}/{/mark}#{length}{/mark}]{/mark}"]
          rescue ArgumentError
            [false]
          end
        end

        # Logs an operation.
        #
        # @param prefix [String] The prefix to apply to the message.
        # @param type [Symbol] The type of operation. Can be `:add` or `:remove`.
        # @param remove_label [String] The label to use for removing.
        # @param add_label [String] The label to use for adding.
        # @param address [String] The address that will be managed.
        # @param config [Configuration] The current configuration.
        # @param quiet [Boolean] Whether to show the message.
        def log_management(prefix, type, remove_label, add_label, address, config, quiet)
          @logger.info(@command.application.console.replace_markers("#{prefix} I will {mark=bright}#{(type == :remove ? remove_label : add_label)}{/mark} address {mark=bright}#{address}{/mark} #{type != :remove ? "to" : "from"} interface {mark=bright}#{config.interface}{/mark}...")) if !quiet
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

        # Check if agent is enabled (that is, we are on OSX).
        #
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if the agent is enabled, `false` otherwise.
        def check_agent_available(quiet)
          rv = true
          if !self.is_osx? then
            logger.fatal("Install akaer on autolaunch is only available on MacOSX.") if !quiet
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
            self.logger.info("Creating the launch agent in {mark=bright}#{launch_agent}{/mark} ...") if !quiet

            args = $ARGV ? $ARGV[0, $ARGV.length - 1] : []

            plist = {"KeepAlive" => false, "Label" => "it.cowtech.akaer", "Program" => (::Pathname.new(Dir.pwd) + $0).to_s, "ProgramArguments" => args, "RunAtLoad" => true}
            ::File.open(launch_agent, "w") {|f|
              f.write(plist.to_json)
              f.flush
            }
            self.execute_command("plutil -convert binary1 \"#{launch_agent}\"")

            true
          rescue
            self.logger.error("Cannot create the launch agent.") if !quiet
            false
          end
        end

        # Deletes a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def delete_agent(launch_agent, quiet)
          begin
            self.logger.info("Deleting the launch agent #{launch_agent} ...") if !quiet
            ::File.delete(launch_agent)
          rescue => e
            self.logger.warn("Cannot delete the launch agent.") if !quiet
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
            self.logger.info("Loading the launch agent ...") if !quiet
            self.execute_command("launchctl load -w \"#{launch_agent}\" > /dev/null 2>&1")
            true
          rescue
            self.logger.error("Cannot load the launch agent.") if !quiet
            false
          end
        end

        # Unoads a OSX system agent.
        #
        # @param launch_agent [String] The agent path.
        # @param quiet [Boolean] Whether to show messages.
        # @return [Boolean] `true` if operation succedeed, `false` otherwise.
        def unload_agent(launch_agent, quiet)
          begin
            self.execute_command("launchctl unload -w \"#{launch_agent}\" > /dev/null 2>&1")
            true
          rescue => e
            self.logger.warn("Cannot unload the launch agent.") if !quiet
            false
          end
        end
    end
  end

  class Application
    attr_reader :config
    attr_reader :command
    attr_accessor :logger

    include Akaer::ApplicationMethods::System

    # Creates a new application.
    #
    # @param command [Mamertes::Command] The current Mamertes command.
    def initialize(command)
      @command = command
      options = @command.application.get_options.reject {|k,v| v.nil? }

      # Setup logger
      Bovem::Logger.start_time = Time.now
      @logger = Bovem::Logger.create(Bovem::Logger.get_real_file(options["log_file"]) || Bovem::Logger.default_file, Logger::INFO)

      # Open configuration
      begin
        @config = Akaer::Configuration.new(options["configuration"], options, @logger)
        @logger = nil
        @logger = self.get_logger
      rescue Bovem::Errors::InvalidConfiguration => e
        @logger ? @logger.fatal(e.message) : Bovem::Logger.create("STDERR").fatal("Cannot log to {mark=bright}#{log_file}{/mark}. Exiting...")
        raise ::SystemExit
      end

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
    # @param force [Boolean] If to force recreation of the instance.
    # @return [Application] The unique (singleton) instance of the application.
    def self.instance(command, force = false)
      @instance = nil if force
      @instance ||= Akaer::Application.new(command)
    end

    private
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