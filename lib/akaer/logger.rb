# encoding: utf-8
#
# This file is part of the akaer gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Akaer
  class Logger < ::Logger
    mattr_accessor :start_time

    def initialize(logdev, shift_age = 0, shift_size = 1048576)
      super(logdev, shift_age, shift_size)

      self.formatter = Proc.new {|severity, datetime, progname, msg|
        color = case severity
          when "DEBUG" then :cyan
          when "INFO" then :green
          when "WARN" then :yellow
          when "ERROR" then :red
          when "FATAL" then :magenta
          else nil
        end

        header = ("[%s T+%0.5f]" %[datetime.strftime("%Y/%b/%d %H:%M:%S"), datetime.to_f - @@start_time.to_f, msg]).bright
        header = header.color(color) if color.present?
        log = "%s %s\n" % [header, msg]
      }
    end
  end
end