# Log info, warnings and errors
# See resat.rb for usage information.
#

require 'logger'

# Add ability to output colored text to console
# e.g.: puts "Hello".red
class String
  def bold; colorize(self, "\e[1m\e[29m"); end
  def grey; colorize(self, "\e[1m\e[30m"); end
  def red; colorize(self, "\e[1m\e[31m"); end
  def dark_red; colorize(self, "\e[31m"); end
  def green; colorize(self, "\e[1m\e[32m"); end
  def dark_green; colorize(self, "\e[32m"); end
  def yellow; colorize(self, "\e[1m\e[33m"); end
  def blue; colorize(self, "\e[1m\e[34m"); end
  def dark_blue; colorize(self, "\e[34m"); end
  def pur; colorize(self, "\e[1m\e[35m"); end
  def colorize(text, color_code)  "#{color_code}#{text}\e[0m" end
end

module Resat

  class LogFormatter
    def call(severity, time, progname, msg)
      msg.gsub!("\n", "\n   ")
      res = ""
      res << "*** " if severity == Logger::ERROR || severity == Logger::FATAL
      res << "#{severity} [#{time.strftime('%H:%M:%S')}]: #{msg.to_s}\n"
      res
    end
  end

  class Log

    # Initialize singleton instance
    def Log.init(options)
      File.delete(options.logfile) rescue nil
      @logger = Logger.new(options.logfile)
      @logger.formatter = LogFormatter.new
      case options.loglevel
        when 'debug' then @logger.level = Logger::DEBUG
        when 'info'  then @logger.level = Logger::INFO
        when 'warn'  then @logger.level = Logger::WARN
        when 'error' then @logger.level = Logger::ERROR
        else              @logger.level = Logger::WARN # default to warning
      end
      @verbose = options.verbose
      @quiet = options.quiet
    end 

    def Log.info(info)
      @logger.info { info } if @logger
      puts "\n#{info}".dark_green if @verbose
    end
    
    def Log.warn(warning)
      @logger.warn { warning } if @logger
      puts "\nWarning: #{warning}".yellow unless @quiet
    end
    
    def Log.error(error)
      @logger.error { error } if @logger
      puts "\nError: #{error}".dark_red
    end

    def Log.fatal(fatal)
      @logger.fatal { fatal } if @logger
      puts "\nCrash: #{fatal}".red
    end
    
    def Log.request(request)
      msg = "REQUEST #{request.method} #{request.path}"
      if request.size > 0
        msg << "\nheaders:"
        request.each_header do |name, value|
          msg << "\n   #{name}: #{value}"
        end
      end
      msg << "\nbody: #{request.body}" unless request.body.nil?
      Log.info(msg)
    end

    def Log.response(response, succeeded = true)
      msg = "RESPONSE #{response.code} #{response.message}"
      if response.size > 0
        msg << "\nheaders:"
        response.each_header do |name, value|
          msg << "\n   #{name}: #{value}"
        end
      end
      msg << "\nbody: #{response.body}" unless response.body.nil?
      if succeeded
        Log.info(msg)
      else
        Log.warn(msg)
      end
    end

  end    
end
