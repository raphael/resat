# Resat response handler
# Allows defining a handler that gets the request and response objects for custom processing 
# Handler should be a module and expose the following methods:
#   - :process takes two argumnents: first argument is an instance of Net::HTTPRequest while
#     second argument is an instance of Net::HTTPResponse.
#     :process should initialize the value returned by :failures (see below)
#   - :failures which returns an array of error messages when processing
#     the response results in errors or an empty array when the processing
#     is successful.

module Resat

  class Handler
    include Kwalify::Util::HashLike
    attr_accessor :failures

    def prepare
      @failures = []
      Log.info("Running handler '#{@name}'")      
    end
    
    def run(request)
      klass = module_class(@module)
      h = klass.new
      h.process(request.request, request.response)
      @failures += h.failures.values.to_a if h.failures
    end
    
    protected
    
    # Create and cache instance of Class which includes
    # given module.
    def module_class(mod)
      @@modules ||= {}
      unless klass = @@modules[mod]
        klass = Class.new(Object) { include Handler.get_module(mod) }
        @@modules[mod] = klass
      end
      klass
    end

    def self.get_module(name)
      parts = name.split('::')
      index = 0
      res   = Kernel
      index += 1 while (index < parts.size) && (res = res.const_get(parts[index]))
      res
    end
  end
end
