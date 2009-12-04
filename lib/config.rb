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

module Resat

  class Config
   
    DEFAULT_FILE = 'config/resat.yaml'
    
    DEFAULT_SCHEMA_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', 'schemas'))

    DEFAULTS = {
      'base_url' => '',
      'use_ssl' => false,
      'variables' => {}
    }

    def Config.init(filename, schemasdir)
      (Config.methods - (Object.methods + [ 'init', 'valid?', 'method_missing' ])).each { |m| class << Config;self;end.send :remove_method, m.to_sym }
      schemafile = File.join(schemasdir || DEFAULT_SCHEMA_DIR, 'config.yaml')
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
      cfg_file  = filename || DEFAULT_FILE
      config    = parser.parse_file(cfg_file)
      if parser.errors.empty?
        if config.nil?
          Log.error("Configuration file '#{cfg_file}' is empty.")
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
        Log.error("Configuration file '#{cfg_file}' is invalid:\n#{errors}")
        @valid = false
      end
    end

    def Config.valid?
      @valid
    end
    
    def self.method_missing(*args)
      nil
    end

  end
end
