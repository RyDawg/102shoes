require 'merb/test/fake_request'
require 'merb/test/hpricot'
require 'merb/test/multipart'
include HpricotTestHelper

module Merb
  module Test
    module Helper
      include Merb::GeneralControllerMixin
      
      # Create a FakeRequest suitable for passing to Controller.build
      def fake_request(params = {})
        method = method.to_s.upcase
        Merb::Test::FakeRequest.with("/", {:request_method => "GET"}.merge(params))
      end
      
      # For integration/functional testing
      #
      # This helper is the basis of the <tt>get</tt>, <tt>post</tt>, <tt>put</tt>, and <tt>delete</tt> helper
      #
      # By default a fake request is yielded to the block for local modification. 
      # +opts+ takes any options that you want pass to the methods, plus some reserved ones
      # 
      # ===Yielding
      # You can get the request helper to yield either a fake request object, or a controller
      # Do this with the +:yield+ option.  Values can be +:request+, or +:controller+.  +:request+ is default
      # When you yield the controller, it is available inside the block with the controller method, so you don't need to
      # explicitly set it in the block chute.
      # ====Example
      #   request( :get, '/', :yields => :controller) do |controller|
      #     controller.stub!(:render)
      #   end
      # 
      # You can also pass in a fake request object which may be useful if your yielding a controller.
      # Use the opts[:fake_request] to do this.  
      # ====Example
      #   request( :get, '/', :yields => :controller, :fake_request => @my_fake_request) do
      #     controller.stub!(:render)
      #   end
      def request(verb, path, opts = {}, &block)
        response = StringIO.new
        
        yield_to_controller = opts.delete(:yields)
        
        request = opts.delete(:fake_request) || Merb::Test::FakeRequest.with(path_with_options(path, opts), :request_method => (verb.to_s.upcase rescue 'GET'))

        if yield_to_controller == :controller
          request_yielding_controller(request, response, &block)
        else
          request_yielding_request(request, response, &block)
        end
      end
                
      # Makes a get request routed to +path+ with any options encoded into the 
      # request url
      # Example
      # {{{ 
      #   get "/users", :user => {:login => "dave", :email => "email@example.com"} 
      # }}}
      def get(path, opts = {}, &block)
        request("GET", path, opts, &block)
      end
      
      # Makes a post request routed to +path+ with any options encoded into the 
      # request url
      # Example
      # {{{ 
      #   post "/users", :user => {:login => "dave", :email => "email@example.com"} 
      # }}}
      def post(path, opts = {}, &block)
        request("POST",path, opts, &block)
      end
      
      # Makes a put request routed to +path+ with any options encoded into the 
      # request url
      # Example
      # {{{ 
      #   put "/users/1", :user => {:login => "dave", :email => "email@example.com"} 
      # }}}
      def put(path,opts = {}, &block)
        request("PUT",path, opts, &block)
      end
      
      # Makes a delete request routed to +path+ with any options encoded into the request url
      # Example
      # {{{ 
      #   delete "/users/1", :user => {:login => "dave", :email => "email@example.com"} 
      # }}}
      def delete(path, opts= {}, &block)
        request("DELETE",path, opts, &block)
      end
            
      # Posts multipart form data to a path
      # pass the +path+ to send and the parameters.  For file uploads, just include a file as the option value.
      # ===Example
      # multipart_post("/my_collection", :foo => "bar", :user => { :login => "joe", :image => File.open("my_image.png")})
      def multipart_post(path, params = {}, &block)
        multipart_request(path, params.merge!(:request_method => 'POST'), &block)
      end

      # Posts multipart form data to a path
      # Same as +multipart_post+ but used for PUT(ting) data to the server
      def multipart_put(path, params = {}, &block)
        multipart_request(path, params.merge!(:request_method => 'PUT'), &block)
      end
      
      def controller
        @controller
      end
      
      [:body, :status, :params, :cookies, :headers,
        :session, :response, :route].each do |method|
        define_method method do
          controller ? controller.send(method) : nil
        end
      end
      
      # Checks that a route is made to the correct controller etc
      # 
      # === Example
      # with_route("/pages/1", "PUT") do |params|
      #   params[:controller].should == "pages"
      #   params[:action].should == "update"
      #   params[:id].should == "1"
      # end
      def with_route(the_path, _method = "GET")
        _fake_request = Merb::Test::FakeRequest.with(the_path, :request_method => _method)
        result = Merb::Router.match(_fake_request, {})
        yield result[1] if block_given?
        result
      end 

      def fixtures(*files)
        files.each do |name|
          klass = Kernel::const_get(Inflector.classify(Inflector.singularize(name)))
          entries = YAML::load_file(File.dirname(__FILE__) + "/fixtures/#{name}.yaml")
          entries.each do |name, entry|
            klass::create(entry)
          end
        end
      end


      # Dispatches an action to a controller.  Defaults to index.  
      # The opts hash, if provided will act as the params hash in the controller
      # and the params method in the controller is infact the provided opts hash
      # This controller is based on a fake_request and does not go through the router
      # 
      # === Simple Example
      #  {{{
      #    controller, result = dispatch_to(Pages, :show, :id => 1, :title => "blah")
      #  }}}
      #
      # === Complex Example
      # By providing a block to the dispatch_to method, the controller may be stubbed or mocked prior to the 
      # actual dispatch action being called.
      #   {{{
      #     controller, result = dispatch_to(Pages, :show, :id => 1) do |controller|
      #       controller.stub!(:render).and_return("rendered response")
      #     end
      #   }}}
      def dispatch_to(controller, action = :index, opts = {})
        klass = controller.class == Class ? controller : controller.class
        @controller = klass.build(fake_request)
        @controller.stub!(:params).and_return(opts.merge(:controller => klass.name.downcase, :action => action.to_s).to_mash)
        yield @controller if block_given?
        [@controller, @controller.dispatch(action.to_sym)]
      end
      
      def path_with_options(path, opts)
        path = path << "?" << params_to_query_string(opts) unless opts.empty?
        path
      end
      
      protected
      
      def request_yielding_request(request, response, &block)
        # response = StringIO.new
        # @request = Merb::Test::FakeRequest.with(path, :request_method => (verb.to_s.upcase rescue 'GET'))
        @request = request
        
        yield @request if block_given?
      
        @controller, @action = Merb::Dispatcher.handle @request, response
      end
      
      def request_yielding_controller(request, response, &block)
        # response = StringIO.new
        # @request = Merb::Test::FakeRequest.with(path, :request_method => (verb.to_s.upcase rescue 'GET'))
        @request = Merb::Request.new(request)

        check_request_for_route(@request)
        
        dispatch_fake_request(@request, response, &block)
      end
      
      def multipart_request(path, params = {}, &block)
        response = StringIO.new
        request = request_with_multipart_params(path, params)
        check_request_for_route(request)
        dispatch_fake_request(request, response, &block)
      end
      
      
      def check_request_for_route(request)
        if request.route_params.empty?
          raise ControllerExceptions::BadRequest, "No routes match the request"
        elsif request.controller_name.nil?
          raise ControllerExceptions::BadRequest, "Route matched, but route did not specify a controller" 
        end
      end
      
      # Used for yielding a controller with request and multipart helpers
      def dispatch_fake_request(request, response, status = 200, &block)
        klass = request.controller_class
        @controller = klass.build(request, response, status)
        
        @controller.send(:setup_session)
         # This will be a mock framework agnostic way of ensuring setup_session is not done again
        class << @controller
          def setup_session; true; end
        end
        
        yield @controller if block_given?

        @controller.dispatch(request.action)
        [@controller, request.action]
        
        rescue => exception
          exception = Dispatcher.send(:controller_exception, exception)
          @controller, @action = Dispatcher.send(:dispatch_exception, request, response, exception)
      end
      
      def request_with_multipart_params(path, params = {})
        request_method = params.delete(:request_method) || "GET"
        request = Merb::Test::FakeRequest.new(:request_uri => path)
        m = Merb::Test::Multipart::Post.new(params)
        body, head = m.to_multipart
        request['REQUEST_METHOD'] = request_method
        request['CONTENT_TYPE'] = head
        request['CONTENT_LENGTH'] = body.length
        request.post_body = body
        Merb::Request.new(request)
      end
      
    end
  end
end

class Object
  # Checks that an object has assigned an instance variable of name
  # :name
  # 
  # ===Example in a spec
  #  @my_obj.assings(:my_value).should == @my_value
  def assigns(attr)
    self.instance_variable_get("@#{attr}")
  end
end

