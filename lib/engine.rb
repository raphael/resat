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

    def initialize(options)
      @options        = options
      @failures       = Hash.new
      @run_count      = 0
      @ignored_count  = 0
      @requests_count = 0
      @skipped_count  = 0
    end
    
    # Was test run successful?
    def succeeded?
      @failures.size == 0
    end

    # Run all scenarios and set attributes accordingly
    def run
      begin
        if File.directory?(@options.target)
          files = FileSet.new(@options.target, %w{.yml .yaml})
        else
          files = [@options.target]
        end
         files.each do |file|
          runner = ScenarioRunner.new(file, @options.schemasdir, @options.config, @options.variables, @options.stoponerror)
          @ignored_count += 1 if runner.ignored?
          @skipped_count += 1 unless runner.valid?
          if runner.valid? && !runner.ignored?
            runner.run
            @run_count += 1
            @requests_count += runner.requests_count
            @failures[file] = runner.failures unless runner.failures.empty?
          else
            unless runner.valid?
              Log.info "Skipping '#{file}' (#{runner.parser_errors})"
            end
            Log.info "Ignoring '#{file}'" if runner.ignored?
          end
        end 
      rescue Exception => e
        Log.error("Something really bad happened#{': ' unless e.message.empty?}#{e.message}")
        backtrace = e.backtrace.inject("") { |msg, s| msg << "#{s}\n" }
        Log.fatal("#{e.message}#{': ' unless e.message.empty?}#{backtrace}")
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

