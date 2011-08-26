# Ruby classes to help consume the daylife API
#
# Author: Conor Hunt - conor.hunt AT gmail DOT com - 5/29/2007
#
# Modified by Subramanya Sastry - subbu@newstrust.net - 5/11/2009
# Upgrade to V4.8 of the API + migrated to libxml-ruby
#
# To get an API key and to learn more about the daylife API go to http://developer.daylife.com
#
# Example Usage:
#
# require 'daylife'
# a = Daylife::API.new('your api key','sharedsecret')
# r = a.execute('search','getRelatedArticles', :query => 'sam adams', :limit => 5)
# r.articles.each {|a| puts a.headline }
# puts r.articles[1].source.daylife_url

require 'xml'
require 'net/http'
require 'md5'
require 'cgi'

module Daylife
  class API
    DEFAULT_PROTOCOL = 'xmlrest'
    DEFAULT_VERSION = '4.8'
    DEFAULT_SERVER = 'freeapi.daylife.com'
    
    CORE_IDENTIFIER_MAP = { 'search'  => [:query],
                            'topic'   => [:name],
                            'article' => [:article_id, :url],   # Either is okay
                            'quote'   => [:quote_id],
                            'image'   => [:image_id] }
    
    def initialize(access_key, shared_secret, options = {})
      @protocol = options[:protocol] || DEFAULT_PROTOCOL
      @version = options[:version] || DEFAULT_VERSION
      @server = options[:server] || DEFAULT_SERVER
      
      @access_key = access_key
      @shared_secret = shared_secret
    end
    
    def execute(service_name, method_name, parameters = {})
      # Create the signature
      core_identifier = parameters[:core_identifier] || parameters[CORE_IDENTIFIER_MAP[service_name].find { |p| parameters[p] }]
      parameters[:signature] = Digest::MD5.hexdigest(@access_key + @shared_secret + core_identifier) unless parameters[:signature]
      
      # Convert Time objects to strings with correct format
      parameters[:start_time] = parameters[:start_time].strftime("%Y-%m-%d %H:%M:%S") if(parameters[:start_time] and parameters[:start_time].kind_of? Time)
      parameters[:end_time] = parameters[:end_time].strftime("%Y-%m-%d %H:%M:%S") if(parameters[:end_time] and parameters[:end_time].kind_of? Time)
    
      # Build the URL  
      parameters[:accesskey] = @access_key      
      url = "http://#{@server}/#{@protocol}/publicapi/#{@version}/#{service_name}_#{method_name}"
      param_string = parameters.collect {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join("&")
      url += "?" + param_string if parameters.length > 0
      
      http_response = Net::HTTP.get_response(URI.parse(url))
      case http_response
      when Net::HTTPSuccess then
        Daylife::Response.new(http_response.body)
      when Net::HTTPClientError then
        raise Exception.new("Couldn't access the Daylife API service: Got #{http_response.code}: #{http_response.message}")
      end
    end
  end

  class Response
    attr_accessor :document
    attr_accessor :root

    def initialize(response)
      @document = XML::Parser.string(response, :options => XML::Parser::Options::NOENT | XML::Parser::Options::NOBLANKS).parse
      @nodes = Daylife::Node.new(@document.find('/response/payload')[0])
    end

    def code
      @document.find("/response/code")[0].content.to_i
    end

    def message
      @document.find("/response/message")[0].content
    end

    def success?
      self.code == 2001
    end
    
    # Pass through missing methods to the daylife node for easy access to the api responses
    def method_missing(name, *args)
      @nodes.send(name, args)
    end
  end

  # This class represents a level in the Daylife response XML, used for easy access to the API results
  class Node
    include Enumerable
  
    def initialize(node)
      @node = node
    end
  
      # In all these methods below, use "entries", not "children"
      # because children is only defined for compound elements, not arrays.
      # But, entries is defined in all cases, and is an alias for children
      # for compound elements
    def each
      @node.entries.each {|e| yield Daylife::Node.new(e) }
    end
  
    def [](index)
      return Daylife::Node.new(@node.entries[index])
    end
  
    def size
      return @node.entries.size
    end
  
    def method_missing(name, *args)
      return nil if @node.kind_of? Array
    
      name = name.to_s
    
        # If there is an 's' then assume this is an array of elements we are trying to access
      if name.reverse[0..0] == 's'
        return Daylife::Node.new(@node.find("#{name[0..name.length-2]}").entries)
      else
        elem = @node.find(name)
        if elem.size == 0
          raise Exception.new("Could not find element with name #{name}")
        elsif (elem[0].children.size > 1)
            # If the element has > 1 child elements then we assume it has no content
          return Daylife::Node.new(elem[0])
        else
          elem = elem[0]
          value = elem.content
          value = value.to_i if(type = elem.attributes["type"] and (type == 'int4' or type == 'int8'))
          value = Time.parse(value) if (name == 'timestamp')
          return value
        end
      end
    end
  end
end
