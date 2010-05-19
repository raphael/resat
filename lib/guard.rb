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

    def prepare(variables)
      @timeout ||= 120
      @period ||= 5
      @failures = []
      variables.substitute!(@pattern)
      Log.info("Waiting for guard #{@name} with pattern /#{@pattern.to_s}/")
    end
    
    def wait(request)
      r = Regexp.new(@pattern)
      r.match(request.get_response_field(@field, @target))
      expiration = DateTime.now + @timeout
      while !Regexp.last_match && DateTime.now < expiration && request.failures.empty?
        sleep @period
        request.send
        r.match(request.get_response_field(@field, @target))
      end
      @failures << "Guard '#{@name}' timed out waiting for field '#{@field}' with pattern '#{@pattern ? @pattern : '<NONE>'}' from response #{@target}." if !Regexp.last_match
    end
  end

end
 
