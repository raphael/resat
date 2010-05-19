# Resat scenario variables
# Manages variables and provides substitution.
# See resat.rb for usage information.
#

require 'singleton'

module Resat

  class Variables

    attr_reader :vars, :marked_for_save, :exported

    # Initialize instance
    def initialize
      @@exported = Hash.new unless defined? @@exported
      @vars = @@exported.dup
    end

    # Replace occurrences of environment variables in +raw+ with their value
    def substitute!(raw)
      if raw.kind_of?(String)
        scans = Array.new
        raw.scan(/[^\$]*\$(\w+)+/) { |scan| scans << scan }
        scans.each do |scan|
          scan.each do |var|
            raw.gsub!('$' + var, @vars[var]) if @vars.include?(var)
          end
        end
      elsif raw.kind_of?(Array)
        raw.each { |i| substitute!(i) }
      elsif raw.kind_of?(Hash)
        raw.each { |k, v| substitute!(v) }
      end
    end
    
    def [](key)
      vars[key]
    end

    def []=(key, value)
      vars[key] = value
    end

    def include?(key)
      vars.include?(key)
    end
    
    def empty?
      vars.empty?
    end
    
    def all
      vars.sort
    end

    # Load variables from given file
    def load(file, schemasdir)
      schemafile = File.join(schemasdir, 'variables.yaml')
      schema = Kwalify::Yaml.load_file(schemafile)
      validator = Kwalify::Validator.new(schema)
      parser = Kwalify::Yaml::Parser.new(validator)
      serialized_vars = parser.parse_file(file)
      parser.errors.push(Kwalify::ValidationError.new("No variables defined")) unless serialized_vars
      if parser.errors.empty?
        serialized_vars.each { |v| vars[v['name']] = v['value'] }
      else
        Log.warn("Error loading variables from '#{file}': #{KwalifyHelper.parser_error(parser)}")
      end
    end
    
    # Save variables to given file
    def save(file)
      serialized_vars = []
      vars.each do |k, v|
        if marked_for_save.include?(k)
          serialized_vars << { 'name' => k, 'value' => v }
        end
      end
      File.open(file, 'w') do |out|
        YAML.dump(serialized_vars, out)
      end
    end
    
    def mark_for_save(key)
      @marked_for_save << key
    end      
    
    # Exported values will be kept even after new instance is initialized
    def export(key)
      @@exported[key] = @vars[key]
    end      
    
  end

end
