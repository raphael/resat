# Classes automatically hydrated with Kwalify from YAML definition
# See resat.rb for usage information.
#
module Resat  

  class Scenario
    include Kwalify::Util::HashLike # defines [], []= and keys?
    attr_accessor :name, :includes, :steps
    def ignore
      @ignore || false
    end
  end
  
  class Step
    include Kwalify::Util::HashLike
    attr_accessor :request, :filters
  end
  
  class ApiRequest
    include Kwalify::Util::HashLike
    attr_accessor :operation, :custom, :resource, :id, :params, :headers, :valid_codes
    def format
      @format || "xml"
    end
  end
  
  class CustomOperation
    include Kwalify::Util::HashLike
    attr_accessor :name, :type
    def separator
      @separator || "/"
    end
  end

  class Guard
    include Kwalify::Util::HashLike
    attr_accessor :target, :field, :pattern
    def period
      @period || 5
    end
    def timeout
      @timeout || 120
    end                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 
  end
  
  class Filter
    include Kwalify::Util::HashLike
    attr_accessor :name, :target, :guards, :required_fields, :validators, :extractors
    def is_empty
      @is_empty || false
    end
  end
  
  class Validator
    include Kwalify::Util::HashLike
    attr_accessor :field, :pattern
    def is_empty
      @is_empty || false
    end
  end
  
  class Extractor
    include Kwalify::Util::HashLike
    attr_accessor :field, :pattern, :variable
  end

end