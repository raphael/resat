# Helper methods that wrap common Kwalify use case
#

require 'kwalify'

module Resat
  
  class KwalifyHelper
    
    # Create new parser from given schema file
    def KwalifyHelper.new_parser(schema_file)
      schema = Kwalify::Yaml.load_file(schema_file)
      validator = Kwalify::Validator.new(schema)
      res = Kwalify::Yaml::Parser.new(validator)
      res.data_binding = true
      res
    end

    # Format error message from parser errors
    def KwalifyHelper.parser_error(parser)
      first = true
      parser.errors.inject("") do |msg, e|
        msg << "\n" unless first
        first = false if first
        msg << "#{e.linenum}:#{e.column} [#{e.path}] #{e.message}"
      end
    end

  end

end