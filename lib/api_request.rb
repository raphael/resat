# API request
# See resat.rb for usage information.
#

require 'uri'
require 'rexml/document'
require 'json'
require File.join(File.dirname(__FILE__), 'net_patch')

module Resat

  class ApiRequest
    include Kwalify::Util::HashLike
    attr_reader :request, :response, :send_count, :failures

    # Prepare request so 'send' can be called
    def prepare(variables, config)
      @format ||= 'xml'
      @failures = []
      @send_count = 0
      @config_delay = config.delay
      @config_use_ssl = config.use_ssl

      # 1. Normalize call fields
      @headers ||= []
      @params ||= []
      # Clone config values so we don't mess with them when expanding variables
      config.headers.each do |h|
        value = @headers.detect { |header| header['name'] == h['name'] }
        @headers << { 'name' => h['name'].dup, 'value' => h['value'].dup } unless value
      end if config.headers
      config.params.each do |p|
        value = @params.detect { |header| header['name'] == h['name'] }
        @params << { 'name' => h['name'].dup, 'value' => h['value'].dup } unless value
      end if config.params && request_class.REQUEST_HAS_BODY
      variables.substitute!(@params)
      variables.substitute!(@headers)

      # 2. Build URI
      variables.substitute!(@id) if @id
      uri_class = (@use_ssl || @use_ssl.nil? && config.use_ssl) ? URI::HTTPS : URI::HTTP
      port = @port || config.port || uri_class::DEFAULT_PORT
      variables.substitute!(port)
      host = @host || config.host
      variables.substitute!(host)
      @uri = uri_class.build( :host => host, :port => port )
      base_url = "/#{@base_url || config.base_url}/".squeeze('/')
      variables.substitute!(base_url)
      path = @path
      unless path
        path = "#{base_url}#{@resource}"
        path = "#{path}/#{@id}" if @id
        path = "#{path}.#{@format}" if @format && !@format.empty? && !@custom
        path = "#{path}#{@custom.separator}#{@custom.name}" if @custom
      end
      variables.substitute!(path)
      @uri.merge!(path)

      # 3. Build request
      case @operation
        when 'index', 'show' then request_class = Net::HTTP::Get
        when 'create'        then request_class = Net::HTTP::Post
        when 'update'        then request_class = Net::HTTP::Put
        when 'destroy'       then request_class = Net::HTTP::Delete
      else
        if type = (@type || @custom && @custom.type)
          case type
            when 'get'    then request_class = Net::HTTP::Get
            when 'post'   then request_class = Net::HTTP::Post
            when 'put'    then request_class = Net::HTTP::Put
            when 'delete' then request_class = Net::HTTP::Delete
          end
        else
          @failures << "Missing request type for request on '#{@resource}'."
          return
        end
      end
      @request = request_class.new(@uri.to_s)
      username = @username || config.username
      variables.substitute!(username) if username
      password = @password || config.password
      variables.substitute!(password) if password
      if username && password
        @request.basic_auth(username, password)
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

    # Actually send the request
    def send
      sleep(delay_seconds) # Delay request if needed
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = @config_use_ssl
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
      !!get_response_field(field, target)
    end

    # Get value of response header or body field
    def get_response_field(field, target)
      return unless @response
      return @response[field] if target == 'header'
      return @response.body if field.nil? || field.empty?
      json = JSON.load(@response.body) rescue nil
      res = nil
      if json
        res = json_field(json, field)
      else
        doc = REXML::Document.new(@response.body)
        elem = doc.elements[field]
        res = elem.get_text.to_s if elem
      end
      res
    end

    protected
    
    # Retrieve JSON body field
    def json_field(json, field)
      return nil unless json
      fields = field.split('/')
      fields.each do |field|
        if json.is_a?(Array)
          json = json[field.to_i]
        else
          json = json[field]
        end
        return nil unless json
      end
      json
    end

    # Calculate number of seconds to wait before sending request
    def delay_seconds
      seconds = nil
      if delay = @delay || @config_delay
        min_delay = max_delay = nil
        if delay =~ /([\d]+)\.\.([\d]+)/
          min_delay = Regexp.last_match[1].to_i
          max_delay = Regexp.last_match[2].to_i
        elsif delay.to_i.to_s == delay
          min_delay = max_delay = delay.to_i
        end
        if min_delay && max_delay
          seconds = rand(max_delay - min_delay + 1) + min_delay
        end
      end
      seconds || 0
    end

  end

end
