# This module provides helper style functionality to all controllers.
module Merb 
  module GeneralControllerMixin
    include Merb::ControllerExceptions
    
    # Returns a URL according to the defined route.  Accepts the path and
    # an options hash.  The path specifies the route requested.  The options 
    # hash fills in the dynamic parts of the route.
    #
    # Merb routes can often be one-way; if they use a regex to define
    # the route, then knowing the controller & action won't be enough
    # to reverse-generate the route.  However, if you use the default
    # /controller/action/id?query route, +default_route+ can generate
    # it for you.
    #
    # For easy reverse-routes that use a Regex, be sure to also add
    # a name to the route, so +url+ can find it.
    # 
    # Nested resources such as:
    #
    #  r.resources :blogposts do |post|
    #    post.resources :comments
    #  end
    #
    # Provide the following routes:
    #
    #   [:blogposts, "/blogposts"]
    #   [:blogpost, "/blogposts/:id"]
    #   [:edit_blogpost, "/blogposts/:id/edit"]
    #   [:new_blogpost, "/blogposts/new"]
    #   [:custom_new_blogpost, "/blogposts/new/:action"]
    #   [:comments, "/blogposts/:blogpost_id/comments"]
    #   [:comment, "/blogposts/:blogpost_id/comments/:id"]
    #   [:edit_comment, "/blogposts/:blogpost_id/comments/:id/edit"]
    #   [:new_comment, "/blogposts/:blogpost_id/comments/new"]
    #   [:custom_new_comment, "/blogposts/:blogpost_id/comments/new/:action"]
    #
    #
    # ==== Parameters
    #
    # :route_name: - Symbol that represents a named route that you want to use, such as +:edit_post+.
    # :new_params: - Parameters to be passed to the generated URL, such as the +id+ for a record to edit.
    #
    # ==== Examples
    #
    #  @post = Post.find(1)
    #  @comment = @post.comments.find(1)
    #
    #  url(:blogposts)                                    # => /blogposts
    #  url(:new_post)                                     # => /blogposts/new
    #  url(:blogpost, @post)                              # => /blogposts/1
    #  url(:edit_blogpost, @post)                         # => /blogposts/1/edit
    #  url(:custom_new_blogpost, :action => 'alternate')  # => /blogposts/new/alternate
    #   
    #  url(:comments, :blogpost_id => @post)         # => /blogposts/1/comments
    #  url(:new_comment, :blogpost_id => @post)      # => /blogposts/1/comments/new
    #  url(:comment, @comment)                    # => /blogposts/1/comments/1
    #  url(:edit_comment, @comment)               # => /blogposts/1/comments/1/edit
    #  url(:custom_new_comment, :blogpost_id => @post)
    #
    #  url(:page => 2)                            # => /posts/show/1?page=2
    #  url(:new_post, :page => 3)                 # => /posts/new?page=3
    #  url('/go/here', :page => 3)                # => /go/here?page=3
    #
    #  url(:controller => "welcome")              # => /welcome
    #  url(:controller => "welcome", :action => "greet")
    #                                             # => /welcome/greet
    #
    def url(route_name = nil, new_params = {})
      if route_name.is_a?(Hash)
        new_params = route_name
        route_name = nil
      end
      
      url = if new_params.respond_to?(:keys) && route_name.nil? &&
        !(new_params.keys & [:controller, :action, :id]).empty?
          url_from_default_route(new_params)
        elsif route_name.nil? && !route.regexp?
          url_from_route(route, new_params)
        elsif route_name.nil?
          request.path + (new_params.empty? ? "" : "?" + params_to_query_string(new_params))
        elsif route_name.is_a?(Symbol)
          url_from_route(route_name, new_params)
        elsif route_name.is_a?(String)
          route_name + (new_params.empty? ? "" : "?" + params_to_query_string(new_params))
        else
          raise "URL not generated: #{route_name.inspect}, #{new_params.inspect}"
        end
      url = Merb::Config[:path_prefix] + url if Merb::Config[:path_prefix]
      url
    end

    def url_from_route(symbol, new_params = {})
      if new_params.respond_to?(:new_record?) && new_params.new_record?
        symbol = "#{symbol}".singularize.to_sym
        new_params = {}
      end
      route = symbol.is_a?(Symbol) ? Merb::Router.named_routes[symbol] : symbol
      unless route
        raise "URL could not be constructed. Route symbol not found: #{symbol.inspect}" 
      end

      path = route.generate(new_params, params)
      keys = route.symbol_segments
      
      if new_params.is_a? Hash
        if ext = format_extension(new_params)
          new_params.delete(:format)
          path += "." + ext
        end
        extras = new_params.reject{ |k, v| keys.include?(k) }
        path += "?" + params_to_query_string(extras) unless extras.empty?
      end
      path
    end
    
    # this is pretty ugly, but it works.  TODO: make this cleaner
    def url_from_default_route(new_params)
      query_params = new_params.reject do |k,v|
        [:controller, :action, :id, :format].include?(k)
      end
      controller = get_controller_for_url_generation(new_params)
      url = "/#{controller}"
      if new_params[:action] || new_params[:id] ||
                new_params[:format] || !query_params.empty?
        action = new_params[:action] || params[:action]
        url += "/#{action}"
      end
      if new_params[:id]
        url += "/#{new_params[:id]}"
      end
      if format = new_params[:format]
        format = params[:format] if format == :current
        url += ".#{format}"
      end
      unless query_params.empty?
        url += "?" + params_to_query_string(query_params)
      end
      url
    end

    protected

    # Creates query string from params, supporting nested arrays and hashes.
    # ==== Example
    #   params_to_query_string(:user => {:filter => {:name => "quux*"}, :order => ["name"]})
    #   # => user[filter][name]=quux%2A&user[order][]=name
    def params_to_query_string(value, prefix = nil)
      case value
      when Array
        value.map { |v|
          params_to_query_string(v, "#{prefix}[]")
        } * "&"
      when Hash
        value.map { |k, v|
          params_to_query_string(v, prefix ? "#{prefix}[#{escape(k)}]" : escape(k))
        } * "&"
      else
        "#{prefix}=#{escape(value)}"
      end
    end
    
    # +format_extension+ dictates when named route URLs generated by the url
    # method will have a file extension. It will return either nil or the format 
    # extension to append.
    #
    # ==== Configuration Options
    #
    # By default, non-HTML URLs will be given an extension. It is posible 
    # to override this behaviour by setting +:use_format_in_urls+ in your 
    # Merb config (merb.yml) to either true/false.
    #
    # +true+  Results in all URLs (even HTML) being given extensions.
    #         This effect is often desirable when you have many formats and dont
    #         wish to treat .html any differently than any other format. 
    # +false+ Results in no URLs being given extensions and +format+
    #         gets treated just like any other param (default).
    #
    # ==== Method parameters
    # 
    # +new_params+ - New parameters to be appended to the URL
    #
    # ==== Examples
    #
    #   url(:post, :id => post, :format => 'xml')
    #   # => /posts/34.xml
    #
    #   url(:accounts, :format => 'yml')
    #   # => /accounts.yml
    #
    #   url(:edit_product, :id => 3, :format => 'html')
    #   # => /products/3
    #
    def format_extension(new_params={})
      format = params.merge(new_params)[:format] || 'html'
      if format != 'html' || always_use_format_extension?
        format || 'html'
      end
    end
    
    def always_use_format_extension?
      Merb::Config[:use_format_in_urls]
    end
    
        
    # Creates an MD5 hashed token based on the current time.
    #
    # ==== Example
    #   make_token
    #   # => "b9a82e011694cc13a4249731b9e83cea" 
    #
    def make_token
      require 'digest/md5'
      Digest::MD5.hexdigest("#{inspect}#{Time.now}#{rand}")
    end

    # Escapes the string representation of +obj+ and escapes
    # it for use in XML.
    #
    # ==== Parameter
    #
    # +obj+ - The object to escape for use in XML.
    #
    def escape_xml(obj)
      obj.to_s.gsub(/[&<>"']/) { |s| Merb::Const::ESCAPE_TABLE[s] }
    end
    alias h escape_xml
    alias html_escape escape_xml
  
    def escape(s)
      ::Merb::Request.escape(s)
    end

    # Unescapes a string (i.e., reverse URL escaping).
    #
    # ==== Parameter 
    #
    # +s+ - String to unescape.
    #
    def unescape(s)
      ::Merb::Request.unescape(s)
    end
    
    
    private
    # Used for sepccing
    def get_controller_for_url_generation(options)
      raise "Controller Not Specified" unless options[:controller]
      options[:controller]
    end
      
  end
end
