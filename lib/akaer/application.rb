# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "cowtech-lib"
require "ipaddr"

class Fixnum
  def i(num = 3)
    self.to_s.rjust(num, "0")
  end
end

module Akaer
  class Application < Cowtech::Lib::Script
    def self.start
      self.new
    end

    def initialize
      Akaer::Logger.start_time = Time.now
      super(:args => {:name => "Interface aliases", :version => 1.0, :description => "A small utility to add aliases to network interfaces.", :usage => "Usage: #{ARGV[0]} [OPTIONS] [add|remove]"})
    end

    def add_options
      @options_parser << [
        {:name => "configuration", :short => "-c", :long => "--configuration", :type => :string, :help => "Configuration file. By default is the standard output", :meta => "FILE", :required => false, :default => "~/.akaer_config"},
        {:name => "interface", :short => "-i", :long => "--interface", :type => :string, :help => "Interface", :meta => "INTERFACE", :required => false, :default => "lo0"},
        {:name => "addresses", :short => "-A", :long => "--addresses", :type => :list, :help => "Addresses to add", :required => false, :default => []},
        {:name => "start-address", :short => "-s", :long => "--start-address", :type => :string, :help => "Starting address (not used if --addresses is specified).", :meta => "ADDRESS", :required => false, :default => "10.0.0.1"},
        {:name => "aliases", :short => "-S", :long => "--aliases", :type => :int, :help => "Number of aliases to add", :meta => "NUMBER", :required => false, :default => 5},
        {:name => "log-file", :short => "-l", :long => "--log-file", :type => :string, :help => "Log file. By default is the standard output", :meta => "FILE", :required => false, :default => "STDOUT"},
        {:name => "log-level", :short => "-L", :long => "--log-level", :type => :int, :help => "The default log level. Valid values are from 0 to 5 where 0 means \"all messages\".", :meta => "NUMBER", :required => false, :default => Logger::INFO},
        {:name => "dry-run", :short => "-n", :long => "--dry-run", :type => :bool, :help => "Do not really execute actions."},
        {:name => "quiet", :short => "-q", :long => "--quiet", :type => :bool, :help => "Do not show any message", :required => false, :default => false}
      ]
    end

    def create_logger(file, level = Logger::INFO)
      file = case file
        when "STDOUT" then $stdout
        when "STDERR" then $stderr
        else file
      end

      rv = Akaer::Logger.new(file)
      rv.level = level.to_i
      rv
    end

    def execute_command(interface, action, ip, prefix = "")
      prefix += " " if !prefix.blank?
      @logger.info("#{prefix}#{(action == "add" ? "Adding" : "Removing").bright} alias #{ip.bright} #{action == "add" ? "to" : "from"} interface #{interface.bright}.")
      system("sudo ifconfig #{interface} #{action == "add" ? "alias" : "-alias"} #{ip}")
    end

    def run
      @logger = self.create_logger(@options_parser["log-file"], @options_parser["log-level"])

      command = (@options_parser.args[0] || "add").downcase
      aliases = []
      target_address = ""

      # Parse configuration file
      configuration = Akaer::Configuration.load(@options_parser["configuration"], @logger)

      # Now merge with the options
      @options_parser[].each_pair do |option, value|
        key = option.to_s.gsub("-", "_")
        configuration[key] = value if configuration.has_key?(key) && @options_parser.provided?(option)
      end

      # Instantiate the logger
      logger = self.create_logger(configuration.log_file, configuration.log_level)

      # Create address
      if !["add", "remove"].include?(command) then
        @logger.fatal("\"Please choose an action between \"add\" or \"remove\".")
        abort
      end

      begin
        if configuration.addresses.blank? then
          target_address = configuration.start_address
          temp = IPAddr.new(target_address)

          [configuration.aliases, 1].max.times do
            aliases << temp.to_s
            temp = temp.succ
            target_address = temp.to_s
          end
        else
          configuration.addresses.each do |t|
            target_address = t
            aliases << IPAddr.new(target_address)
          end
        end
      rescue ArgumentError => e
        logger.fatal("\"#{target_address}\" is not a valid IP address.")
        abort
      end

      if !@options_parser["dry-run"] then
        total = aliases.length
        rj = total.to_s.length
        aliases.each_with_index do |a, i|
          prefix = "[#{(i + 1).to_s.rjust(rj, "0")}/#{total}]"
          if !self.execute_command(configuration.interface, command, a, prefix) then
            logger.fatal("#{command == "add" ? "Adding" : "Removing"} alias #{a} failed.")
            abort
          end
        end
      else
        @logger.info("I will #{command.bright} #{aliases.length == 1 ? "this alias" : "these aliases"} #{command == "add" ? "to" : "from"} interface #{configuration.interface.bright}: #{aliases.collect {|a| a.bright}.join(", ")}.")
      end
    end
  end
end