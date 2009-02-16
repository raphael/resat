# === Synopsis 
#   resat - RightScale API Tester
#   
#   This application allows making automated REST requests optionally followed 
#   by validation. It reads scenarios defined in YAML files and executes the
#   corresponding steps. A step consist of a REST request followed by any 
#   number of filters.
#
#   Scenarios are defined as YAML documents that must adhere to the Kwalify
#   schemas defined in schemas/scenarios.yaml. See the comments in this
#   file for additional information.
#
#   resat is configured through a YAML configuration file which defines
#   information that applies to all requests including the host name,
#   base url, whether to use SSL, common headers and body parameters and
#   optionally a username and password to be used with basic authentication.
#   This configuration file should be located in config/resat.yaml by default.
#
# === Examples
#   Run the scenario defined in scenario.yaml:
#     resat scenario.yaml
#
#   Execute scenarios defined in the 'scenarios' directory and its
#   sub-directories:
#     resat scenarios
#
#   Only execute the scenarios defined in the current directory, do not execute
#   scenarios found in sub-directories:
#     resat -n .
#
# === Usage 
#   resat [options] target
#
#   For help use: resat -h
#
# === Options
#   -h, --help            Display help message
#   -v, --version         Display version, then exit
#   -q, --quiet           Output as little as possible, override verbose
#   -V, --verbose         Verbose output
#   -n, --norecursion     Don't run scenarios defined in sub-directories
#   -d, --define NAME:VAL Define global variable (can appear multiple times,
#                         escape ':' with '::')
#   -c, --config PATH     Config file path (config/resat.yaml by default)
#   -s, --schemasdir DIR  Path to schemas directory (schemas/ by default)
#   -l, --loglevel LVL    Log level: debug, info, warn, error (info by default)
#   -f, --logfile PATH    Log file path (resat.log by default)
#
# === Author
#   Raphael Simon
#

require 'rubygems'
require 'lib/rdoc_patch'
require 'lib/engine'
require 'lib/log'
require 'lib/config'
require 'optparse' 
require 'rdoc/usage'
require 'ostruct'
require 'date'
require 'benchmark'

module Resat
  class App
    VERSION = '0.0.1'

    def initialize(arguments)
      @arguments = arguments

      # Set defaults
      @options = OpenStruct.new
      @options.verbose = false
      @options.quiet = false
      @options.norecursion = false
      @options.variables = {}
      @options.configfile = "config/resat.yaml"
      @options.schemasdir = 'schemas'
      @options.loglevel = "info"
      @options.logfile = "resat.log"
    end

    # Parse options, check arguments, then run tests
    def run
      if parsed_options? && arguments_valid?
        output_options if @options.verbose
        tms = Benchmark.measure { run_tests }
        Log.info tms.format("\t\tUser\t\tSystem\t\tReal\nDuration:\t%u\t%y\t%r")
      else
        output_usage
        @return_value = 1
      end
      exit @return_value
    end

    protected

    def parsed_options?
      opts = OptionParser.new
      opts.on('-h', '--help')           { output_help }
      opts.on('-v', '--version')        { output_version; exit 0 }
      opts.on('-q', '--quiet')          { @options.quiet = true }
      opts.on('-V', '--verbose')        { @options.verbose = true }
      opts.on('-n', '--norecursion')    { @options.norecursion = true }
      opts.on('-d', '--define VAR:VAL') { |v| @options.variables.merge!(var_hash(v)) }
      opts.on('-c', '--configfile CFG') { |cfg| @options.configfile = cfg }
      opts.on('-s', '--schemasdir DIR') { |dir| @options.schemasdir = dir }
      opts.on('-l', '--loglevel LEVEL') { |level| @options.loglevel = level }
      opts.on('-f', '--logfile LOG')    { |log| @options.logfile = log }

      opts.parse!(@arguments) rescue return false

      process_options
      true
    end

    # Build variable hash from command line option
    def var_hash(var)
      parts = var.split('::')
      key = value = ''
      key_built = false
      parts.each_index do |idx|
        part = parts[idx]
        if key_built
          value = value + ':' + (part || '')
        else
          if part.include?(':')
            subparts = part.split(':')
            part = subparts[0]
            value = subparts[1] || ''
            key_built = true
          end
          key = key + ':' if idx > 0
          key = key + (part || '')
        end
      end
      { key => value }
    end

    # Post-parse processing of options
    def process_options
      @options.verbose = false if @options.quiet
      @options.loglevel.downcase!
      @options.target = ARGV[0] unless ARGV.empty? # We'll catch that later
    end

    def output_options
      puts "Options:".blue
      @options.marshal_dump.each do |name, val|
        puts "  #{name}".dark_blue + " = #{val}"
      end
    end

    # Check arguments
    def arguments_valid?
      valid = ARGV.size == 1
      if valid
        unless %w{ debug info warn error }.include? @options.loglevel
          Log.error "Invalid log level '#{@options.loglevel}'"
          valid = false
        end
        unless File.file?(@options.configfile)
          Log.error "Non-existent config file '#{@options.configfile}'"
          valid = false
        end
        unless File.directory?(@options.schemasdir)
          Log.error "Non-existent schemas directory '#{@options.schemasdir}'"
          valid = false
        end
        unless File.exists?(ARGV[0])
          Log.error "Non-existent target '#{ARGV[0]}'"
          valid = false
        end
      end
      valid
    end

    def output_help
      output_version
      RDoc::usage_from_file(__FILE__)
      exit 0
    end

    def output_usage
      RDoc::usage_from_file(__FILE__, 'usage')
      exit 0
    end

    def output_version
      puts "#{File.basename(__FILE__)} - RightScale Automated API Tester v#{VERSION}\n".blue
    end

    def run_tests
      Log.init(@options)
      engine = Engine.new(@options)
      engine.run
      if engine.succeeded?
        puts engine.summary.dark_blue
        @return_value = 0
      else
        puts engine.summary.dark_red
        @return_value = 1
      end
      unless @options.quiet
        msg = ""
        msg << "#{engine.requests_count} API call#{'s' if engine.requests_count > 1}*"
        if engine.ignored_count > 1
          msg << "*#{engine.ignored_count} scenario#{'s' if engine.ignored_count > 1} ignored*"
        end
        if engine.skipped_count > 1
          msg << "*#{engine.skipped_count} YAML file#{'s' if engine.skipped_count >1} skipped" 
        end
        msg.gsub!('**', ', ')
        msg.delete!('*')
        puts msg.dark_blue
      end
    end
  end
end

# Create and run the app
app = Resat::App.new(ARGV)
app.run
