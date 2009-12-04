# Resat test scenario, sequence of api calls and filters.
# See resat.rb for usage information.
#

require 'kwalify/util/hashlike'
require File.join(File.dirname(__FILE__), 'kwalify_helper')
require File.join(File.dirname(__FILE__), 'config')
require File.join(File.dirname(__FILE__), 'variables')
require File.join(File.dirname(__FILE__), 'api_request')
require File.join(File.dirname(__FILE__), 'guard')
require File.join(File.dirname(__FILE__), 'filter')
require File.join(File.dirname(__FILE__), 'handler')

module Resat

  class ScenarioRunner

    attr_accessor :requests_count, :parser_errors, :failures

    # Instantiate new scenario runner with given YAML definition document and
    # schemas directory.
    # If parsing the scenario YAML definition fails then 'valid?' returns false
    # and 'parser_errors' contains the error messages.
    def initialize(doc, schemasdir, config, variables, failonerror, dry_run)
      @schemasdir     = schemasdir
      @valid          = true
      @ignored        = false
      @name           = ''
      @failures       = Array.new
      @requests_count = 0
      @failonerror    = failonerror
      @dry_run        = dry_run
      parse(doc)
      if @valid
        Config.init(config || @cfg_file, schemasdir)
        @valid = Config.valid?
        if @valid
          Variables.reset
          Variables.load(Config.input, schemasdir) if Config.input && File.readable?(Config.input)
          Config.variables.each { |v| Variables[v['name']] = v['value'] } if Config.variables
          variables.each { |k, v| Variables[k] = v } if variables
        end
      end
    end
    
    def ignored?;   @ignored;         end
    def valid?;     @valid;           end # parser_errors contains the details
    def succeeded?; @failures.empty?; end

    # Run the scenario.
    # Once scenario has run check 'succeeded?'.
    # If 'succeeded?' returns false, use 'failures' to retrieve error messages.
    def run
      return if @ignored || !@valid
      Log.info("-" * 80 + "\nRunning scenario #{@name}")
      unless Variables.empty?
        info_msg = Variables.all.inject("Using variables:") do |msg, (k, v)|
          msg << "\n   - #{k}: #{v}"
        end
        Log.info(info_msg)
      end
      @steps.each_index do |index|
        @current_step = index
        @current_file = @steps[index][:origin]
        step = @steps[index][:step]
        case step
        when ApiRequest
          @requests_count += @request.send_count if @request # Last request
          @request = step
          @request.prepare
          @request.send unless @dry_run
        when Guard
          step.prepare
          step.wait(@request) unless @dry_run
        when Filter, Handler
          step.prepare
          step.run(@request) unless @dry_run 
        end
        puts step.inspect if step.failures.nil?
        step.failures.each { |f| add_failure(f) }
        break if @failonerror && !succeeded? # Abort on failure
      end

      @requests_count += @request.send_count
      Variables.save(Config.output) if Config.output
    end

    protected

    # Parse YAML definition file and set 'valid?' and 'parser_errors' 
    # accordingly
    def parse(doc)
      parser = KwalifyHelper.new_parser(File.join(@schemasdir, 'scenarios.yaml'))
      scenario = parser.parse_file(doc)
      if parser.errors.empty?
        @ignored = !scenario || scenario.ignore
        @cfg_file = File.expand_path(File.join(File.dirname(doc), scenario.config)) if scenario.config
        unless @ignored
          @name = scenario.name
          @steps = Array.new
          scenario.includes.each do |inc|
            process_include(inc, File.dirname(doc))
          end if scenario.includes
          scenario.steps.each do |step|
            @steps << { :step => step.request, :origin => doc }
            if step.filters
              @steps.concat(step.filters.map { |f| { :step => f, :origin => doc } })
            end
            if step.handlers
              @steps.concat(step.handlers.map { |h| { :step => h, :origin => doc } })
            end
            if step.guards
              @steps.concat(step.guards.map { |g| { :step => g, :origin => doc } })
            end
          end if scenario.steps
        end
      else
        @valid = false
        @parser_errors = KwalifyHelper.parser_error(parser)
      end
    end
    
    def process_include(inc, dir)
       if File.directory?(File.join(dir, inc))
        includes = FileSet.new(File.join(dir, inc), %{.yml .yaml})
      else
        path = find_include(inc, dir)
        if path
          includes = [path]
        else
          Log.warn("Cannot find include file or directory '#{inc}'")
          includes = []
        end
      end
      includes.each { |i| include_steps(i) }
    end

    def include_steps(path)
      parser = KwalifyHelper.new_parser(File.join(@schemasdir, 'scenarios.yaml'))
      scenario = parser.parse_file(path)
      if parser.errors.empty?
        scenario.includes.each do |inc|
           process_include(inc, File.dirname(path))
        end if scenario.includes
        scenario.steps.each do |step|
          @steps << { :step => step.request, :origin => path }
          if step.filters
            @steps.concat(step.filters.map { |f| { :step => f, :origin => path } })
          end
          if step.handlers
            @steps.concat(step.handlers.map { |h| { :step => h, :origin => path } })
          end
          if step.guards
            @steps.concat(step.guards.map { |g| { :step => g, :origin => path } })
          end
        end
      else
        Log.error("Cannot include file '#{path}': #{parser.errors.join(", ")}")
      end
    end
    
    # Path to include file if it's found, nil otherwise
    def find_include(inc, dir)
      # File extension is optional in YAML definition
      # We'll use the one in the current folder if we can't find it in the same
      # folder as the including file
      path = test if File.file?(test = File.join(dir, inc + '.yml'))
      path = test if File.file?(test = File.join(dir, inc + '.yaml'))
      path = test if File.file?(test = File.join(dir, inc))
      return path if path
      subs = Dir.entries(dir).select { |f| File.directory?(f) }
      subs = subs - FileSet::IGNORED_FOLDERS
      subs.detect { |sub| find_include(inc, File.join(dir, sub)) }
    end


    # Append error message to list of failures
    def add_failure(failure)
      @failures << "Step ##{@current_step} from '#{@current_file}': #{failure}"
    end
    
  end

  # Classes automatically hydrated with Kwalify from YAML definition
 
  class Scenario
    include Kwalify::Util::HashLike # defines [], []= and keys?
    attr_accessor :name, :config, :includes, :steps
    def ignore; @ignore || false; end
  end
  
  class Step
    include Kwalify::Util::HashLike
    attr_accessor :request, :filters, :handlers, :guards
  end
  
  class CustomOperation
    include Kwalify::Util::HashLike
    attr_accessor :name, :type
    def separator; @separator || "/"; end
  end

end
