module Merb
  class Dispatcher
    
    DEFAULT_ERROR_TEMPLATE = Erubis::MEruby.new((File.read(
	File.join(Merb.root, 'app/views/exceptions/internal_server_error.html.erb')) rescue "Internal Server Error!"))
        
    class << self
      
      def use_mutex=(val)
        @@use_mutex = val
      end
      
      @@mutex = Mutex.new
      @@use_mutex = ::Merb::Config[:use_mutex]
      # This is where we grab the incoming request REQUEST_URI and use that in
      # the merb RouteMatcher to determine which controller and method to run.
      # Returns a 2 element tuple of: [controller, action]
      #
      # ControllerExceptions are rescued here and redispatched.
      # Exceptions still return [controller, action]
      def handle(http_request, response)
        start   = Time.now
        request = Merb::Request.new(http_request)
        Merb.logger.info("Params: #{request.params.inspect}")
        Merb.logger.info("Cookies: #{request.cookies.inspect}")
        # user friendly error messages
        if request.route_params.empty?
          raise ControllerExceptions::BadRequest, "No routes match the request"
        elsif request.controller_name.nil?
          raise ControllerExceptions::BadRequest, "Route matched, but route did not specify a controller" 
        end
        Merb.logger.debug("Routed to: #{request.route_params.inspect}")
        # set controller class and the action to call
        klass = request.controller_class
        dispatch_action(klass, request.action, request, response)
      rescue => exception
        Merb.logger.error(Merb.exception(exception))
        exception = controller_exception(exception)
        dispatch_exception(request, response, exception)
      end
        
      private 
      
      # setup the controller and call the chosen action 
      def dispatch_action(klass, action, request, response, status=200)
        # build controller
        controller = klass.build(request, response, status)
        # complete setup benchmarking
        #controller._benchmarks[:setup_time] = Time.now - start
        if @@use_mutex
          @@mutex.synchronize { controller.dispatch(action) }
        else
          controller.dispatch(action)
        end
        [controller, action]
      end
      
      # Re-route the current request to the Exception controller
      # if it is available, and try to render the exception nicely
      # if it is not available then just render a simple text error
      def dispatch_exception(request, response, exception)
        klass = Exceptions rescue Controller
        request.params[:original_params] = request.params.dup rescue {}
        request.params[:original_session] = request.session.dup rescue {}
        request.params[:original_cookies] = request.cookies.dup rescue {}
        request.params[:exception] = exception
        request.params[:action] = exception.name
        dispatch_action(klass, exception.name, request, response, exception.class::STATUS)
      rescue => dispatch_issue
        dispatch_issue = controller_exception(dispatch_issue)  
        # when no action/template exist for an exception, or an
        # exception occurs on an InternalServerError the message is
        # rendered as simple text.
        # ControllerExceptions raised from exception actions are 
        # dispatched back into the Exceptions controller
        if dispatch_issue.is_a?(ControllerExceptions::NotFound)
          dispatch_default_exception(klass, request, response, exception)
        elsif dispatch_issue.is_a?(ControllerExceptions::InternalServerError)
          dispatch_default_exception(klass, request, response, dispatch_issue)
        else
          exception = dispatch_issue
          retry
        end
      end
      
      # if no custom actions are available to render an exception
      # then the errors will end up here for processing
      def dispatch_default_exception(klass, request, response, e)
        controller = klass.build(request, response, e.class::STATUS)
        if e.is_a? ControllerExceptions::Redirection
          controller.headers.merge!('Location' => e.message)
          controller.instance_variable_set("@_body", %{ }) #fix
        else
          @exception = e # for ERB
          controller.instance_variable_set("@_body", DEFAULT_ERROR_TEMPLATE.result(binding))
        end
        [controller, e.name]
      end
      
      # Wraps any non-ControllerException errors in an 
      # InternalServerError ready for displaying over HTTP
      def controller_exception(e)
        e.kind_of?(ControllerExceptions::Base) ?
          e : ControllerExceptions::InternalServerError.new(e) 
      end
      
    end # end class << self
  end
end
