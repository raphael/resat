# Resat test scenario, sequence of api calls and filters.
# See resat.rb for usage information.
#

require 'kwalify'
require 'kwalify/util/hashlike'
require 'uri'
require 'net/http'
require 'net/https'
require 'rexml/document'
require File.join(File.dirname(__FILE__), 'file_set')
require File.join(File.dirname(__FILE__), 'net_patch')

require 'ruby-debug'
module Resat

  class ScenarioRunner
    attr_accessor :requests_count, :parser_errors, :failures

    # Instantiate new scenario runner with given YAML definition document and
    # schemas directory.
    # If parsing the scenario YAML definition fails then 'valid?' returns false
    # and 'parser_errors' contains the error messages.
    def initialize(doc, schemasdir, variables)
      @schemasdir = schemasdir
      @valid = true
      @ignored = false
      @requests_count = 0
      @variables = variables || {}
      Config.variables.each { |v| @variables[v['name']] = v['value'] }
      @name = ''
      @failures = Array.new
      parse(doc)
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
      @steps.each_index do |index|
        @current_step = index
        @current_file = @steps[index][:origin]
        step = @steps[index][:step]
        make_request(step) if step.kind_of?(ApiRequest)
        wait_for_guard(step) if step.kind_of?(Guard)
        run_filter(step) if step.kind_of?(Filter)
        return unless succeeded? # Abort on failure
      end
    end

    protected

    # Parse YAML definition file and set 'valid?' and 'parser_errors' 
    # accordingly
    def parse(doc)
      parser = new_parser
      scenario = parser.parse_file(doc)
      if parser.errors.empty?
        @ignored = !scenario || scenario.ignore
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
            if step.guards
              @steps.concat(step.guards.map { |g| { :step => g, :origin => doc } })
            end
          end if scenario.steps
        end
      else
        @valid = false
        @parser_errors = parser_error(parser.errors)
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
      parser = new_parser
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
          if step.guards
            @steps.concat(step.guards.map { |g| { :step => g, :origin => path } })
          end
        end
      else
        Log.error("Cannot include file '#{path}': #{parser_error(parser.errors)}")
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
    
    def parser_error(errors)
      first = true
      errors.inject("") do |msg, e|
        msg << "\n" unless first
        first = false if first
        msg << "#{e.linenum}:#{e.column} [#{e.path}] #{e.message}"
      end
    end
    
    def new_parser
      schemafile = File.join(@schemasdir, 'scenarios.yaml')
      schema = Kwalify::Yaml.load_file(schemafile)
      validator = Kwalify::Validator.new(schema)
      res = Kwalify::Yaml::Parser.new(validator)
      res.data_binding = true
      res
    end

    def make_request(call)
      # 1. Normalize call fields
      call.headers ||= []
      call.params ||= []
      # Clone config values so we don't mess with them when expanding variables
      Config.headers.each do |h| 
        call.headers << { 'name' => h['name'].dup, 'value' => h['value'].dup }
      end if Config.headers
      Config.params.each do |p|
        call.params << { 'name' => p['name'].dup, 'value' => p['value'].dup }
      end if Config.params && request_class.REQUEST_HAS_BODY
      resolve_vars!(call.params)
      resolve_vars!(call.headers)

      # 2. Build URI
      resolve_vars!(call.id) if call.id
      uri_class = Config.use_ssl ? URI::HTTPS : URI::HTTP
      port = Config.port || uri_class::DEFAULT_PORT
      @uri = uri_class.build( :host => Config.host, 
                             :port => port,
                             :path => Config.base_url )
      path = "#{call.resource}/"
      path = "#{path}/#{call.id}" if call.id
      path = "#{path}/#{call.format}" if call.format && call.id
      path = "#{path}#{call.custom.separator}#{call.custom.name}" if call.custom
      @uri.merge!(path)

      # 3. Build request
      case call.operation
        when 'index', 'show'  then request_class = Net::HTTP::Get
        when 'create'         then request_class = Net::HTTP::Post
        when 'update'         then request_class = Net::HTTP::Put
        when 'destroy'        then request_class = Net::HTTP::Delete
      else
        if call.custom
          case call.custom.type
            when 'get'    then request_class = Net::HTTP::Get
            when 'post'   then request_class = Net::HTTP::Post
            when 'put'    then request_class = Net::HTTP::Put
            when 'delete' then request_class = Net::HTTP::Delete
          end
        else
          add_failure("Missing request operation for request on '#{call.resource}'.")
          return
        end
      end
      @request = request_class.new(@uri.to_s)
      if Config.username && Config.password
        @request.basic_auth(Config.username, Config.password)
      end
      form_data = Hash.new
      call.headers.each { |header| @request[header['name']] = header['value'] }
      call.params.each { |param| form_data[param['name']] = param['value'] }
      @request.set_form_data(form_data) unless form_data.empty?
      Log.request(@request)

      # 4. Send request and check response code
      @oks = call.valid_codes.map { |r| r.to_s } if call.valid_codes
      @oks ||= %w{200 201 202 203 204 205 206}
      send_request
     end
     
    # Actually send the request
    def send_request
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = Config.use_ssl
      begin
        res = http.start { |http| @response = http.request(@request) }
      rescue Exception => e
        add_failure("Exception raised while making request: #{e.message}")
      end
      if succeeded?
        @requests_count += 1
        if @oks.include?(res.code)
          Log.response(@response)
        else
          Log.response(@response, false)
          add_failure("Request returned #{res.code}")
        end
      end
    end
    
    # Wait for guard
    def wait_for_guard(guard)
      pattern = guard.pattern
      resolve_vars!(pattern)
      period = guard.period
      target = guard.target
      r = Regexp.new(pattern)
      r.match(get_field(guard.field, target))
      expiration = DateTime.now + guard.timeout
      while !Regexp.last_match && DateTime.now < expiration && succeeded?
        sleep period
        send_request
        r.match(get_field(guard.field, target))
      end
    end

    # Run given filter
    def run_filter(filter)
      return if @response.nil?
      Log.info("Running filter #{filter.name}")
      target = filter.target
      
      # 1. Validate response
      if target == 'header'
        if !!filter.is_empty != (@response.size == 0)
          add_failure("Response header #{'not ' unless @response.size == 0}empty.")
        end
      else
        if !!filter.is_empty != (@response.body.nil? || @response.body.size <= 1)
          add_failure("Response body #{'not ' if filter.is_empty}empty.")
        end
      end
      
      # 2. Check required fields
      filter.required_fields.each do |field|
        unless has_field?(field, target)
          add_failure("Missing #{target} field '#{field}'.")
        end
      end if filter.required_fields
      
      # 3. Evaluate validators
      filter.validators.each do |v|
        if has_field?(v.field, target)
          field = get_field(v.field, target)
          if v.pattern
            resolve_vars!(v.pattern)
            unless Regexp.new(v.pattern).match(field)
              add_failure("Validator /#{v.pattern} failed on '#{field}' from #{target} field '#{v.field}'.")
            end
          end
          unless !!v.is_empty == field.empty?
            add_failure("#{target.capitalize} field '#{v.field}' #{'not ' if v.is_empty}empty.")
          end
        else
          add_failure("Missing #{target} field '#{v.field}'.")
        end
      end if filter.validators
      
      # 4. Run extractors
      filter.extractors.each do |ex|
        if has_field?(ex.field, target)
          field = get_field(ex.field, target)
          if ex.pattern
            resolve_vars!(ex.pattern)
            Regexp.new(ex.pattern).match(field)
            if Regexp.last_match
              @variables[ex.variable] = Regexp.last_match(1)
            else
              Log.warn("Extraction from response #{target} field '#{ex.field}' ('#{field}') with pattern '#{ex.pattern}' failed.")
            end
          else
            @variables[ex.variable] = field
          end
        end
      end if filter.extractors
    end
    
    # Does response include given header or body field? 
    def has_field?(field, target)
      return unless @response
      return @response.key?(field) if target == 'header'
      doc = REXML::Document.new(@response.body)
      return !doc.elements[field].nil?
    end
    
    # Get value of response header or body field
    def get_field(field, target)
      return unless @response
      return @response[field] if target == 'header'
      doc = REXML::Document.new(@response.body)
      elem = doc.elements[field]
      return elem.get_text.to_s if elem
    end

    # Append error message to list of failures
    def add_failure(failure)
      @failures << "Step ##{@current_step} from '#{@current_file}': #{failure}"
    end
    
    # Replace occurrences of environment variables with their value
    def resolve_vars!(input)
      if input.kind_of?(String)
        scans = Array.new
        input.scan(/[^\$]*\$(\w+)+/) { |scan| scans << scan }
        scans.each do |scan|
          scan.each do |var|
            input.gsub!('$' + var, @variables[var]) if @variables.include?(var)
          end
        end
      elsif input.kind_of?(Array)
        input.each { |i| resolve_vars!(i) }
      elsif input.kind_of?(Hash)
        input.each { |k, v| resolve_vars!(v) }
      end
    end
    
  end

  # Classes automatically hydrated with Kwalify from YAML definition
 
  class Scenario
    include Kwalify::Util::HashLike # defines [], []= and keys?
    attr_accessor :name, :ignore, :includes, :steps
  end
  
  class Step
    include Kwalify::Util::HashLike
    attr_accessor :request, :filters, :guards
  end
  
  class ApiRequest
    include Kwalify::Util::HashLike
    attr_accessor :operation, :custom, :resource, :id, :format, :params, :headers, :valid_codes
  end
  
  class CustomOperation
    include Kwalify::Util::HashLike
    attr_accessor :name, :type, :separator
  end

  class Guard
    include Kwalify::Util::HashLike
    attr_accessor :target, :field, :pattern, :period, :timeout
  end

  class Filter
    include Kwalify::Util::HashLike
    attr_accessor :name, :target, :guards, :is_empty, :required_fields, :validators
    attr_accessor :extractors
  end
  
  class Validator
    include Kwalify::Util::HashLike
    attr_accessor :field, :is_empty, :pattern
  end
  
  class Extractor
    include Kwalify::Util::HashLike
    attr_accessor :field, :pattern, :variable
  end

end
