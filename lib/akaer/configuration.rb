# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Akaer
  class Configuration < Hashie::Dash
    property :interface, :default => "lo0"
    property :addresses, :default => []
    property :start_address, :default => "10.0.0.1"
    property :aliases, :default => 5
    property :log_file, :default => "STDOUT"
    property :log_level, :default => Logger::INFO

    def self.load(file = nil, logger = nil)
      if logger.blank? then
        logger ||= Akaer::Logger.new($stderr)
        logger.level = Logger::INFO
      end

      rv = self.new
      if file.present? then
        begin
          # Open the file
          path = Pathname.new(File.expand_path(file)).realpath
          logger.debug("Using configuration file #{path}.")

          rv.tap do |config|
            eval(File.read(path))
          end
        rescue Errno::ENOENT, LoadError
        rescue Exception
          raise Akaer::Errors::InvalidConfiguration.new("Config file #{file.bright} is not valid.")
        end
      end

      rv
    end
  end
end