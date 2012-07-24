# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

Sickill::Rainbow.enabled = true

module Akaer
  class Logger < ::Logger
    mattr_accessor :global_start_time
    attr_accessor :start_time

    def initialize(logdev, shift_age = 0, shift_size = 1048576)
      super(logdev, shift_age, shift_size)
    end

    def self.create(file, level = Logger::INFO, formatter = nil)
      rv = self.new(self.get_real_file(file))
      rv.level = level.to_i
      rv.formatter = formatter || self.default_formatter
      rv
    end

    def self.get_real_file(file)
      case file
        when "STDOUT" then $stdout
        when "STDERR" then $stderr
        else file
      end
    end

    def self.default_file
      $stdout
    end

    def self.default_formatter
      Proc.new {|severity, datetime, progname, msg|
        color = case severity
          when "DEBUG" then :cyan
          when "INFO" then :green
          when "WARN" then :yellow
          when "ERROR" then :red
          when "FATAL" then :magenta
          else nil
        end

        header = ("[%s T+%0.5f] %s:" %[datetime.strftime("%Y/%b/%d %H:%M:%S"), [datetime.to_f - self.start_time.to_f, 0].max, severity.rjust(5)]).bright
        header = header.color(color) if color.present?
        "%s %s\n" % [header, msg]
      }
    end

    def self.start_time
      @start_time ||= Time.now
    end
  end
end
