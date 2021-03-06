# Resat response filter
# Use response filters to validate responses and/or store response elements in 
# variables.
# Automatically hydrated with Kwalify from YAML definition.
# See resat.rb for usage information.
#

module Resat

  class Filter
    include Kwalify::Util::HashLike
    attr_accessor :failures
    
    def prepare(variables)
      @is_empty ||= false
      @failures = []
      @variables = variables
      Log.info("Running filter '#{@name}'")
    end

    # Run filter on given response
    def run(request)
      @request = request
      @response = request.response
      validate
      extract
    end
    
    # Validate response
    def validate
      unless @response
        @failures << "No response to validate."
        return
      end
      
      # 1. Check emptyness
      if @target == 'header'
        if @is_empty != (@response.size == 0)
          @failures << "Response header #{'not ' if @is_empty}empty."
        end
      else
        if @is_empty != (@response.body.nil? || @response.body.size <= 1)
          @failures << "Response body #{'not ' if @is_empty}empty."
        end
      end
      
      # 2. Check required fields
      @required_fields.each do |field|
        unless @request.has_response_field?(field, target)
          @failures << "Missing #{target} field '#{field}'."
        end
      end if @required_fields
      
      # 3. Evaluate validators
      @validators.each do |v|
        if @request.has_response_field?(v.field, @target)
          field = @request.get_response_field(v.field, @target)
          is_ok = v.is_empty && field.empty?
          is_ok ||= v.pattern && v.pattern.empty? && field.empty?
          if v.pattern && !v.pattern.empty?
            @variables.substitute!(v.pattern)
            is_ok ||= Regexp.new(v.pattern).match(field)
          end
          @failures << "Validator /#{v.pattern} failed on '#{field}' from #{@target} field '#{v.field}'." unless is_ok
        else
          @failures << "Missing #{@target} field '#{v.field}'."
        end
      end if @validators
    end
    
    # Extract elements from response
    def extract
      @extractors.each do |ex|
        @variables.substitute!(ex.field)
        if @request.has_response_field?(ex.field, @target)
          field = @request.get_response_field(ex.field, @target)
          if ex.pattern
            @variables.substitute!(ex.pattern)
            Regexp.new(ex.pattern).match(field)
            if Regexp.last_match
              @variables[ex.variable] = Regexp.last_match(1)
            else
              Log.warn("Extraction from response #{@target} field '#{ex.field}' ('#{field}') with pattern '#{ex.pattern}' failed.")
            end
          else
            @variables[ex.variable] = field
          end
          @variables.mark_for_save(ex.variable) if ex.save
          @variables.export(ex.variable) if ex.export
        else
          Log.warn("Extraction from response #{@target} field '#{ex.field}' failed: field not found.")
        end
      end if @extractors
    end

  end

  # Classes for instances hydrated by Kwalify

  class Validator
    include Kwalify::Util::HashLike
    attr_accessor :field, :is_empty, :pattern
  end
  
  class Extractor
    include Kwalify::Util::HashLike
    attr_accessor :field, :pattern, :variable
    def save; @save || false; end
    def export; @export || false; end
  end
 
end
