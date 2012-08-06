# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A small utility to add aliases to network interfaces.
module Akaer
  # The main Akaer application.
  class Application
    # The {Configuration Configuration} of this application.
    attr_reader :config

    # The arguments passed via command-line.
    attr_reader :args

    # The logger for this application.
    attr_accessor :logger

    # Creates a new application.
    #
    # @param globals [Hash] Global options.
    # @param locals [Hash] Local command options.
    # @param args [Array] Extra arguments.
    def initialize(globals = {}, locals = {}, args = [])
      @args = {
        :global => globals,
        :local => locals,
        :args => args
      }

      # Setup logger
      Bovem::Logger.start_time = Time.now
      @logger = Bovem::Logger.create(Bovem::Logger.get_real_file(@args[:global][:log_file]) || Bovem::Logger.default_file, Logger::INFO)

      # Open configuration
      begin
        overrides = {
          :interface => @args[:global][:interface],
          :addresses => @args[:global][:addresses],
          :start_address => @args[:global][:"start-address"],
          :aliases => @args[:global][:aliases],
          :add_command => @args[:global][:"add-command"],
          :remove_command => @args[:global][:"remove-command"],
          :log_file => @args[:global][:"log-file"],
          :log_level => @args[:global][:"log-level"],
          :dry_run => @args[:global][:"dry-run"],
          :quiet => @args[:global][:quiet]
        }.reject {|k,v| v.nil? }

        @config = Akaer::Configuration.new(@args[:global][:config], overrides, @logger)

        @logger = nil
        @logger = self.get_logger
      rescue Bovem::Errors::InvalidConfiguration => e
        @logger ? @logger.fatal(e.message) : Bovem::Logger.create("STDERR").fatal("Cannot log to #{config.log_file}. Exiting...")
        raise ::SystemExit
      end

      self
    end

    # Checks if we are running on MacOS X.
    # System services are only available on that platform.
    #
    # @return [Boolean] `true` if the current platform is MacOS X, `false` otherwise.
    def is_osx?
      ::Config::CONFIG['host_os'] =~ /^darwin/
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

    # Checks if and address is a valid IPv4 address.
    #
    # @param address [String] The address to check.
    # @return [Boolean] `true` if the address is a valid IPv4 address, `false` otherwise.
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
      @logger ||= Bovem::Logger.create(Bovem::Logger.default_file, @config.log_level, @log_formatter)
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
      rv = []

      if self.config.addresses.present? # We have an explicit list
        rv = self.config.addresses

        # Now filter the addresses
        filters = [type != :ipv6 ? :ipv4 : nil, type != :ipv4 ? :ipv6 : nil].compact
        rv = rv.select {|address|
          filters.any? {|filter| self.send("is_#{filter}?", address) }
        }.compact.uniq
      else
        begin
          ip = IPAddr.new(self.config.start_address.ensure_string)
          raise ArgumentError if (type == :ipv4 && !ip.ipv4?) || (type == :ipv6 && !ip.ipv6?)

          (self.config.aliases > 0 ? self.config.aliases : 5).times do
            rv << ip.to_s
            ip = ip.succ
          end
        rescue ArgumentError
        end
      end

      rv
    end

    # Adds or removes an alias from the interface
    #
    # @param type [Symbol] The operation to execute. Can be `:add` or `:remove`.
    # @param address [String] The address to manage.
    # @return [Boolean] `true` if operation succedeed, `false` otherwise.
    def manage(type, address)
      rv = true

      # Compute the command
      command = (type == :remove) ? self.config.remove_command : self.config.add_command

      # Interpolate
      command = command.gsub("@INTERFACE@", self.config.interface).gsub("@ALIAS@", address) + " > /dev/null 2>&1"

      # Compute the prefix
      @addresses ||= self.compute_addresses
      length = self.pad_number(@addresses.length)
      index = (@addresses.index(address) || 0) + 1
      prefix = ["[".color(:cyan), self.pad_number(index, length.length).bright, "/".color(:cyan), length.bright, "]".color(:cyan)].join("")

      # Now execute
      if !self.config.dry_run then
        @logger.info("#{prefix} #{(type == :remove ? "Removing" : "Adding").bright} address #{address.bright} #{type != :remove ? "to" : "from"} interface #{self.config.interface.bright}...") if !self.config.quiet
        rv = self.execute_command(command)

        # TODO: The end badge.
      else
        @logger.info("#{prefix} I will #{(type == :remove ? "remove" : "add").bright} address #{address.bright} #{type != :remove ? "to" : "from"} interface #{self.config.interface.bright}.") if !self.config.quiet
      end

      rv
    end

    # Adds aliases to the interface.
    #
    # @return [Boolean] `true` if action succedeed, `false` otherwise.
    def action_add
      addresses = self.compute_addresses

      if addresses.present? then
        # Now, for every address, call the command
        addresses.all? {|address|
          self.manage(:add, address)
        }
      else
        @logger.error("No valid addresses to add to the interface found.") if !self.config.quiet
      end
    end

    # Removes aliases from the interface.
    #
    # @return [Boolean] `true` if action succedeed, `false` otherwise.
    def action_remove
      addresses = self.compute_addresses

      if addresses.present? then
        # Now, for every address, call the command
        addresses.all? {|address|
          self.manage(:remove, address)
        }
      else
        @logger.error("No valid addresses to remove from the interface found.") if !self.config.quiet
      end
    end

    # Installs the application into the autolaunch.
    #
    # @return [Boolean] `true` if action succedeed, `false` otherwise.
    def action_install
      logger = get_logger

      if !self.is_osx? then
        logger.fatal("Install akaer on autolaunch is only available on MacOSX.") if !self.config.quiet
        return false
      end

      launch_agent = self.launch_agent_path

      begin
        logger.info("Creating the launch agent in #{launch_agent} ...") if !self.config.quiet

        args = $ARGV ? $ARGV[0, $ARGV.length - 1] : []

        plist = {"KeepAlive" => false, "Label" => "it.cowtech.akaer", "Program" => (::Pathname.new(Dir.pwd) + $0).to_s, "ProgramArguments" => args, "RunAtLoad" => true}
        ::File.open(launch_agent, "w") {|f|
          f.write(plist.to_json)
          f.flush
        }
        self.execute_command("plutil -convert binary1 \"#{launch_agent}\"")
      rescue => e
        logger.error("Cannot create the launch agent.") if !self.config.quiet
        return false
      end

      begin
        logger.info("Loading the launch agent ...") if !self.config.quiet
        self.execute_command("launchctl load -w \"#{launch_agent}\" > /dev/null 2>&1")
      rescue => e
        logger.error("Cannot load the launch agent.") if !self.config.quiet
        return false
      end

      true
    end

    # Uninstalls the application from the autolaunch.
    #
    # @return [Boolean] `true` if action succedeed, `false` otherwise.
    def action_uninstall
      logger = self.get_logger

      if !self.is_osx? then
        logger.fatal("Install akaer on autolaunch is only available on MacOSX.") if !self.config.quiet
        return false
      end

      launch_agent = self.launch_agent_path

      # Unload the launch agent.
      begin
        self.execute_command("launchctl unload -w \"#{launch_agent}\" > /dev/null 2>&1")
      rescue => e
        logger.warn("Cannot unload the launch agent.") if !self.config.quiet
      end

      # Delete the launch agent.
      begin
        logger.info("Deleting the launch agent #{launch_agent} ...")
        ::File.delete(launch_agent)
      rescue => e
        logger.warn("Cannot delete the launch agent.") if !self.config.quiet
        return false
      end

      true
    end

    # Returns a unique (singleton) instance of the application.
    # @param globals [Hash] Global options.
    # @param locals [Hash] Local command options.
    # @param args [Array] Extra arguments.
    # @param force [Boolean] If to force recreation of the instance.
    # @return [Application] The unique (singleton) instance of the application.
    def self.instance(globals = {}, locals = {}, args = [], force = false)
      @instance = nil if force
      @instance ||= Akaer::Application.new(globals, locals, args)
    end
  end
end