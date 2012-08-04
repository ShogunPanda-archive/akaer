# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Akaer
  # This class holds the configuration of the applicaton.
  class Configuration < Bovem::Configuration
    # The default interface to manage. Default: `lo0`.
    property :interface, :default => "lo0"

    # The default list of aliases to add. Default: `[]`.
    property :addresses, :default => []

    # The starting address for sequential aliases. Default: `10.0.0.1`.
    property :start_address, :default => "10.0.0.1"

    # The number of aliases to add. Default: `5`.
    property :aliases, :default => 5

    # The command to run for adding an alias. Default: `sudo ifconfig @INTERFACE@ alias @ALIAS@`.
    property :add_command, :default => "sudo ifconfig @INTERFACE@ alias @ALIAS@"

    # The command to run for removing an alias. Default: `sudo ifconfig @INTERFACE@ alias @ALIAS@`.
    property :remove_command, :default => "sudo ifconfig @INTERFACE@ -alias @ALIAS@"

    # The file to log to. Default is the standard output.
    property :log_file, :default => "STDOUT"

    # The minimum severity to log. Default: `Logger::INFO`.
    property :log_level, :default => Logger::INFO

    # Only show which modifications will be done.
    property :dry_run, :default => false

    # Do not show any message.
    property :quiet, :default => false

    # Creates a new configuration.
    #
    # @param file [String] The file to read.
    # @param overrides [Hash] A set of values which override those set in the configuration file.
    # @param logger [Logger] The logger to use for notifications.
    def initialize(file = nil, overrides = {}, logger = nil)
      super(file, overrides, logger)

      # Make sure some arguments are of correct type
      self.log_file = $stdout if self.log_file == "STDOUT"
      self.log_file = $stderr if self.log_file == "STDERR"
      self.addresses = self.addresses.ensure_array
      self.aliases = self.aliases.to_integer
      self.log_level = self.log_level.to_integer
    end
  end
end