# Resat scenario variables
# Manages variables and provides substitution.
# See resat.rb for usage information.
#

module Resat

  class Variables
    include Singleton

    attr_reader :vars, :marked_for_save, :exported

    # Replace occurrences of environment variables in +raw+ with their value
    def Variables.substitute!(raw)
      instance().substitute!(raw)
    end
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
    
    def Variables.[](key)
      instance().vars[key]
    end

    def Variables.[]=(key, value)
      instance().vars[key] = value
    end

    def Variables.include?(key)
      instance().vars.include?(key)
    end
    
    def Variables.empty?
      instance().vars.empty?
    end
    
    def Variables.all
      instance().vars.sort
    end

    def Variables.load(file, schemasdir)
      schemafile = File.join(schemasdir, 'variables.yaml')
      schema = Kwalify::Yaml.load_file(schemafile)
      validator = Kwalify::Validator.new(schema)
      parser = Kwalify::Yaml::Parser.new(validator)
      serialized_vars = parser.parse_file(file)
      parser.errors.push(Kwalify::ValidationError.new("No variables defined")) unless serialized_vars
      if parser.errors.empty?
        vars = instance().vars
        serialized_vars.each { |v| vars[v['name']] = v['value'] }
      else
        Log.warn("Error loading variables from '#{file}': #{KwalifyHelper.parser_error(parser)}")
      end
    end
    
    def Variables.save(file)
      serialized_vars = []
      i = instance()
      i.vars.each do |k, v|
        if i.marked_for_save.include?(k)
          serialized_vars << { 'name' => k, 'value' => v }
        end
      end
      File.open(file, 'w') do |out|
        YAML.dump(serialized_vars, out)
      end
    end
    
    def Variables.mark_for_save(key)
      instance().mark_for_save(key)
    end
    def mark_for_save(key)
      @marked_for_save << key
    end      
    
    # Exported values will be kept even after a call to reset
    def Variables.export(key)
      instance().export(key)
    end
    def export(key)
      @exported[key] = @vars[key]
    end      
    
    def Variables.reset
      instance().reset
    end
    def reset
      @vars = @exported.clone
      @marked_for_save = Array.new
    end

    protected

    def initialize
      @exported = Hash.new
      reset
      super
    end

  end

end
