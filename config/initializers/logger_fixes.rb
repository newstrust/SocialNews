## SSS: Revert rails changes to Ruby's logger
## Code courtesy http://wiki.rubyonrails.org/rails/pages/HowtoConfigureLogging
class Logger
  def format_message(severity, timestamp, progname, msg)
    if (!@formatter.nil?)
      @formatter.call(severity, timestamp, progname, msg)
    else
      @default_formatter.call(severity, timestamp, progname, msg)
    end
  end
end

## Create a formatter that outputs messages the way we want it!
class RailsFormatter < Logger::Formatter
  def call(severity, timestamp, progname, msg)
    datetime_format='%Y-%m-%d %H:%M:%S';
    "[#{timestamp.strftime(datetime_format)}] #{severity}: #{msg}\n" 
  end
end

# SSS: Turned off in migration to rails 2.3
### Use the buffered logger, but, format messages the way we want it!
### What use is logging without a darned timestamp?
#module ActiveSupport
#  class BufferedLogger
#      # Timestamp formatting that we want
#    @@datetime_format='%Y-%m-%d %H:%M:%S';
#
#      # Map severity integer values back to their names
#    @@severity_names = Array.new
#    Severity.constants.each { |c| v = eval("Severity::#{c}"); @@severity_names[v] = c }
#
#      # Override the logger add msg
#    def add(severity, message = nil, progname = nil, &block)
#      return if @level > severity
#      message = (message || (block && block.call) || progname).to_s
#      # If a newline is necessary then create a new message ending with a newline.
#      # Ensures that the original message is not mutated.
#      message = "[#{Time.now.strftime(@@datetime_format)}] #{@@severity_names[severity]}: #{message}\n" unless message[-1] == ?\n
#      @buffer << message
#      auto_flush
#      message
#    end
#  end
#end
