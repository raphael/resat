# Log info, warnings and errors
# See resat.rb for usage information.
#

require 'logger'

# Add ability to output colored text to console
# e.g.: puts "Hello".red
class String
  def bold; colorize(self, "\e[1m\e[29m"); end
  def grey; colorize(self, "\e[30m"); end
  def red; colorize(self, "\e[1m\e[31m"); end
  def dark_red; colorize(self, "\e[31m"); end
  def green; colorize(self, "\e[1m\e[32m"); end
  def dark_green; colorize(self, "\e[32m"); end
  def yellow; colorize(self, "\e[1m\e[33m"); end
  def blue; colorize(self, "\e[1m\e[34m"); end
  def dark_blue; colorize(self, "\e[34m"); end
  def pur; colorize(self, "\e[1m\e[35m"); end
  def colorize(text, color_code)  
    # Doesn't work with the Windows prompt...
    RUBY_PLATFORM =~ /(win|w)32$/ ? text : "#{color_code}#{text}\e[0m" 
  end
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

    LEVELS = %w{ debug info warn error fatal }
    
    # Initialize singleton instance
    def Log.init(options)
      File.delete(options.logfile) rescue nil
      options.logfile = 'resat.log' unless File.directory?(File.dirname(options.logfile))
      @logger = Logger.new(options.logfile)
      @logger.formatter = LogFormatter.new
      @level = LEVELS.index(options.loglevel.downcase) if options.loglevel
      @level = Logger::WARN unless @level # default to warning
      @logger.level = @level
      @verbose = options.verbose
      @quiet = options.quiet
    end 
    
    def Log.debug(debug)
      @logger.debug { debug } if @logger
      puts "\n#{debug}".grey if @level == Logger::DEBUG
    end

    def Log.info(info)
      puts "\n#{info}".dark_green if @verbose
      @logger.info { info } if @logger
    end
    
    def Log.warn(warning)
      puts "\nWarning: #{warning}".yellow unless @quiet
      @logger.warn { warning } if @logger
    end
    
    def Log.error(error)
      puts "\nError: #{error}".dark_red
      @logger.error { error } if @logger
    end

    def Log.fatal(fatal)
      puts "\nCrash: #{fatal}".red
      @logger.fatal { fatal } if @logger
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
