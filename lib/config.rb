# Configuration information read from given configuration file 
# ('config/resat.yaml' by default).
#
# Configuration example:
#
# # Hostname used for API calls
# host:     my.rightscale.com
# 
# # Common base URL to all API calls
# base_url: '/api/acct/71/'
# 
# # Use HTTPS?
# use_ssl:  yes
# 
# # Basic auth username if any
# username: raphael@rightscale.com
# 
# # Basic auth password if any
# password: Secret
# 
# # Common request headers for all API calls
# headers:
#   - name:  X-API-VERSION
#     value: '1.0'
#     
# # Common parameters for all API calls
# params:
#
# See resat.rb for usage information.
#

require 'kwalify'
require File.join(File.dirname(__FILE__), 'log')

module Resat

  class Config
   
    DEFAULTS = {
      'base_url' => '',
      'use_ssl' => false,
    }

    def Config.init(filename, schemasdir = 'schemas')
      schemafile = File.join(schemasdir, 'config.yaml')
      unless File.exists?(schemafile)
        Log.error("Missing configuration file schema '#{schemafile}'")
        @valid = false
        return
      end
      schema    = Kwalify::Yaml.load_file(schemafile)
      validator = Kwalify::Validator.new(schema)
      parser    = Kwalify::Yaml::Parser.new(validator)
      @valid    = true
      @config   = { 'use_ssl' => false, 'username' => nil, 'password' => nil, 'port' => nil }
      config = parser.parse_file(filename)
      if parser.errors.empty?
        if config.nil?
          Log.error("Configuration file '#{filename}' is empty.")
          @valid = false
        else
          @config.merge!(config)
          # Dynamically define the methods to forward to the config hash
          @config.each_key do |meth|
            (class << self; self; end).class_eval do
              define_method meth do |*args|
                @config[meth] || DEFAULTS[meth]
              end
            end
          end
        end
      else
        errors = parser.errors.inject("") do |msg, e|
          msg << "#{e.linenum}:#{e.column} [#{e.path}] #{e.message}\n\n"
        end
        Log.error("Configuration file '#{filename}' is invalid:\n#{errors}")
        @valid = false
      end
    end

    def Config.valid?
      @valid
    end

  end
end
