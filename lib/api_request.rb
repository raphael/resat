# API request
# See resat.rb for usage information.
#

require 'kwalify/util/hashlike'
require 'uri'
require 'net/http'
require 'net/https'
require 'rexml/document'

module Resat
  
  class ApiRequest
    include Kwalify::Util::HashLike
    attr_accessor :response, :send_count, :failures

    # Prepare request so 'send' can be called
    def prepare
      @format ||= 'xml'
      @failures = []
      @send_count = 0

      # 1. Normalize call fields
      @headers ||= []
      @params ||= []
      # Clone config values so we don't mess with them when expanding variables
      Config.headers.each do |h| 
        @headers << { 'name' => h['name'].dup, 'value' => h['value'].dup }
      end if Config.headers
      Config.params.each do |p|
        @params << { 'name' => p['name'].dup, 'value' => p['value'].dup }
      end if Config.params && request_class.REQUEST_HAS_BODY
      Variables.substitute!(@params)
      Variables.substitute!(@headers)

      # 2. Build URI
      Variables.substitute!(@id) if @id
      uri_class = (@use_ssl || @use_ssl.nil? && Config.use_ssl) ? URI::HTTPS : URI::HTTP
      port = @port || Config.port || uri_class::DEFAULT_PORT
      @uri = uri_class.build( :host => @host || Config.host, 
                             :port => port,
                             :path => @base_url || Config.base_url )
      path = "#{@resource}/"
      path = "#{path}/#{@id}" if @id
      path = "#{path}.#{@format}" if @format && @id
      path = "#{path}#{@custom.separator}#{@custom.name}" if @custom
      @uri.merge!(path)

      # 3. Build request
      case @operation
        when 'index', 'show' then request_class = Net::HTTP::Get
        when 'create'        then request_class = Net::HTTP::Post
        when 'update'        then request_class = Net::HTTP::Put
        when 'destroy'       then request_class = Net::HTTP::Delete
      else
        if @custom
          case @custom.type
            when 'get'    then request_class = Net::HTTP::Get
            when 'post'   then request_class = Net::HTTP::Post
            when 'put'    then request_class = Net::HTTP::Put
            when 'delete' then request_class = Net::HTTP::Delete
          end
        else
          @failures << "Missing request operation for request on '#{@resource}'."
          return
        end
      end
      @request = request_class.new(@uri.to_s)
      if (@username || Config.username) && (@password || Config.password)
        @request.basic_auth(@username || Config.username, 
                            @password || Config.password)
      end
      form_data = Hash.new
      @headers.each { |header| @request[header['name']] = header['value'] }
      @params.each { |param| form_data[param['name']] = param['value'] }
      @request.set_form_data(form_data) unless form_data.empty?
      Log.request(@request)

      # 4. Send request and check response code
      @oks = @valid_codes.map { |r| r.to_s } if @valid_codes
      @oks ||= %w{200 201 202 203 204 205 206}
     end
     
    # Actually send the request, call 'prepare' first if it wasn't called yet.
    def send
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = Config.use_ssl
      begin
        res = http.start { |http| @response = http.request(@request) }
      rescue Exception => e
        @failures << "Exception raised while making request: #{e.message}"
      end
      if @failures.size == 0
        @send_count += 1
        if @oks.include?(res.code)
          Log.response(@response)
        else
          Log.response(@response, false)
          @failures << "Request returned #{res.code}"
        end
      end
    end
    
    # Does response include given header or body field? 
    def has_response_field?(field, target)
      return unless @response
      return @response.key?(field) if target == 'header'
      doc = REXML::Document.new(@response.body)
      return !doc.elements[field].nil?
    end
    
    # Get value of response header or body field
    def get_response_field(field, target)
      return unless @response
      return @response[field] if target == 'header'
      doc = REXML::Document.new(@response.body)
      elem = doc.elements[field]
      return elem.get_text.to_s if elem
    end

  end

end