# Resat test engine, reads test files and run them.
# See resat.rb for usage information.
#

ENG_DIR = File.dirname(__FILE__)
require File.join(ENG_DIR, 'file_set')
require File.join(ENG_DIR, 'log')
require File.join(ENG_DIR, 'scenario_runner')

module Resat

  class Engine

    attr_accessor :run_count      # Total number of run scenarios
    attr_accessor :requests_count # Total number of HTTP requests
    attr_accessor :ignored_count  # Total number of ignored scenarios
    attr_accessor :skipped_count  # Total number of skipped YAML files
    attr_accessor :failures       # Hash of error messages (string arrays)
                                  # indexed by scenario filename
    attr_accessor :variables      # Hash of variables hashes indexed by
                                  # scenario filename

    def initialize(options)
      @options        = options
      @failures       = Hash.new
      @run_count      = 0
      @ignored_count  = 0
      @requests_count = 0
      @skipped_count  = 0
      @variables      = Hash.new
    end
    
    # Was test run successful?
    def succeeded?
      @failures.size == 0
    end

    # Run all scenarios and set attributes accordingly
    def run(target=nil)
      target ||= @options.target
      begin
        if File.directory?(target)
          files = FileSet.new(target, %w{.yml .yaml})
        elsif File.file?(target)
          files = [target]
        else
          @failures[target] ||= []
          @failures[target] << "Invalid taget #{target}: Not a directory, nor a file"
          return
        end
        schemasdir = @options.schemasdir || Config::DEFAULT_SCHEMA_DIR
        files.each do |file|
          runner = ScenarioRunner.new(file, schemasdir, @options.config, 
                     @options.variables, @options.failonerror, @options.dry_run)
          @ignored_count += 1 if runner.ignored?
          @skipped_count += 1 unless runner.valid?
          if runner.valid? && !runner.ignored?
            runner.run
            @run_count += 1
            @requests_count += runner.requests_count
            if runner.succeeded?
              @variables[file] = runner.variables
            else
              @failures[file] = runner.failures
            end
          else
            unless runner.valid?
              Log.info "Skipping '#{file}' (#{runner.parser_errors})"
            end
            Log.info "Ignoring '#{file}'" if runner.ignored?
          end
        end 
      rescue Exception => e
        Log.error(e.message)
        backtrace = "   " + e.backtrace.inject("") { |msg, s| msg << "#{s}\n" }
        Log.debug(backtrace)
      end
    end

    def summary
      if succeeded?
        case run_count
          when 0 then res = "\nNo scenario to run."
          when 1 then res = "\nOne scenario SUCCEEDED"
          else res = "\n#{run_count} scenarios SUCCEEDED"
        end
      else
        i = 1
        res = "\nErrors summary:\n"
        failures.each do |file, errors|
          res << "\n#{i.to_s}) Scenario '#{file}' failed with: "
          errors.each do |error|
            res << "\n     "
            res << error
          end
          i = i + 1
        end
        res << "\n\n#{i - 1} of #{run_count} scenario#{'s' if run_count > 1} FAILED"
      end
      res
    end
          
  end
end

