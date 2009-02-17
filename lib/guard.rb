# Resat response filter
# Use response filters to validate responses and/or store response elements in 
# variables.
# Automatically hydrated with Kwalify from YAML definition.
# See resat.rb for usage information.
#

module Resat
  
  class Guard
    include Kwalify::Util::HashLike
    attr_accessor :failures
    
    def wait(request)
      Log.info("Waiting for guard #{@name}")
      @timeout ||= 120
      @period ||= 5
      @failures = []
      
      Variables.substitute!(@pattern)
      r = Regexp.new(@pattern)
      r.match(request.get_response_field(@field, @target))
      expiration = DateTime.now + @timeout
      while !Regexp.last_match && DateTime.now < expiration && succeeded?
        sleep period
        request.send
        r.match(request.get_response_field(@field, @target))
      end
      @failures << "Guard '#{@name}' timed out waiting for field '#{@field}' with pattern '#{@pattern ? @pattern : '<NONE>'}' from response #{@target}."
    end
  end

end