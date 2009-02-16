# Resat scenario variables
# Manages variables and provides substitution.
# See resat.rb for usage information.
#

module Resat

  class Variables
    include Singleton
    attr_reader :vars

    # Replace occurrences of environment variables in +raw+ with their value
    def Variables.substitute!(raw)
      instance().substitute!(raw)
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

    # Replace occurrences of environment variables with their value
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

    protected

    def initialize
      @vars = Hash.new
      super
    end

  end

end
