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
          "start-address" => @args[:global]["start-address"],
          :aliases => @args[:global][:aliases],
          "add-command" => @args[:global]["add-command"],
          "remove-command" => @args[:global]["remove-command"],
          "log-file" => @args[:global]["log-file"],
          "log-level" => @args[:global]["log-level"],
          "dry-run" => @args[:global]["dry-run"],
          "quiet" => @args[:global]["quiet"]
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

    # Check if we are running on MacOS X.
    # System services are only available on that platform.
    #
    # @return [Boolean] `true` if the current platform is MacOS X, `false` otherwise.
    def is_osx?
      ::Config::CONFIG['host_os'] =~ /^darwin/
    end

    # Pads a number to make print friendly.
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
      system(command)
    end

    #def execute_command(interface, action, ip, prefix = "")
    #  prefix += " " if !prefix.blank?
    #  @logger.info("#{prefix}#{(action == "add" ? "Adding" : "Removing").bright} alias #{ip.bright} #{action == "add" ? "to" : "from"} interface #{interface.bright}.")
    #  system("sudo ifconfig #{interface} #{action == "add" ? "alias" : "-alias"} #{ip}")
    #end

    #def run
    #  @logger = Akaer::Logger.create(@options_parser["log-file"], @options_parser["log-level"])
    #
    #  command = (@options_parser.args[0] || "add").downcase
    #  aliases = []
    #  target_address = ""
    #
    #  # Parse configuration file
    #  configuration = Akaer::Configuration.load(@options_parser["configuration"], @logger)
    #
    #  # Now merge with the options
    #  @options_parser[].each_pair do |option, value|
    #    key = option.to_s.gsub("-", "_")
    #    configuration[key] = value if configuration.has_key?(key) && @options_parser.provided?(option)
    #  end
    #
    #  # Instantiate the logger
    #  logger = Akaer::Logger.create(configuration.log_file, configuration.log_level)
    #
    #  # Create address
    #  if !["add", "remove"].include?(command) then
    #    @logger.fatal("\"Please choose an action between \"add\" or \"remove\".")
    #    abort
    #  end
    #
    #  begin
    #    if configuration.addresses.blank? then
    #      target_address = configuration.start_address
    #      temp = IPAddr.new(target_address)
    #
    #      [configuration.aliases, 1].max.times do
    #        aliases << temp.to_s
    #        temp = temp.succ
    #        target_address = temp.to_s
    #      end
    #    else
    #      configuration.addresses.each do |t|
    #        target_address = t
    #        aliases << IPAddr.new(target_address)
    #      end
    #    end
    #  rescue ArgumentError => e
    #    logger.fatal("\"#{target_address}\" is not a valid IP address.")
    #    abort
    #  end
    #
    #  if !@options_parser["dry-run"] then
    #    total = aliases.length
    #    rj = total.to_s.length
    #    aliases.each_with_index do |a, i|
    #      prefix = "[#{(i + 1).to_s.rjust(rj, "0")}/#{total}]"
    #      if !self.execute_command(configuration.interface, command, a, prefix) then
    #        logger.fatal("#{command == "add" ? "Adding" : "Removing"} alias #{a} failed.")
    #        abort
    #      end
    #    end
    #  else
    #    @logger.info("I will #{command.bright} #{aliases.length == 1 ? "this alias" : "these aliases"} #{command == "add" ? "to" : "from"} interface #{configuration.interface.bright}: #{aliases.collect {|a| a.bright}.join(", ")}.")
    #  end
    #end


    # Installs the application into the autolaunch.
    #
    # @return [Boolean] `true` if action succedeed, `false` otherwise.

    def action_install
      logger = get_logger

      if !self.is_osx? then
        logger.fatal("Install akaer on autolaunch is only available on MacOSX.")
        return false
      end

      launch_agent = self.launch_agent_path

      begin
        logger.info("Creating the launch agent in #{launch_agent} ...")

        args = $ARGV ? $ARGV[0, $ARGV.length - 1] : []

        plist = {"KeepAlive" => false, "Label" => "it.cowtech.akaer", "Program" => (::Pathname.new(Dir.pwd) + $0).to_s, "ProgramArguments" => args, "RunAtLoad" => true}
        ::File.open(launch_agent, "w") {|f|
          f.write(plist.to_json)
          f.flush
        }
        self.execute_command("plutil -convert binary1 \"#{launch_agent}\"")
      rescue => e
        logger.error("Cannot create the launch agent.")
        return false
      end

      begin
        logger.info("Loading the launch agent ...")
        self.execute_command("launchctl load -w \"#{launch_agent}\" > /dev/null 2>&1")
      rescue => e
        logger.error("Cannot load the launch agent.")
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
        logger.fatal("Install akaer on autolaunch is only available on MacOSX.")
        return false
      end

      launch_agent = self.launch_agent_path

      # Unload the launch agent.
      begin
        self.execute_command("launchctl unload -w \"#{launch_agent}\" > /dev/null 2>&1")
      rescue => e
        logger.warn("Cannot unload the launch agent.")
      end

      # Delete the launch agent.
      begin
        logger.info("Deleting the launch agent #{launch_agent} ...")
        ::File.delete(launch_agent)
      rescue => e
        logger.warn("Cannot delete the launch agent.")
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