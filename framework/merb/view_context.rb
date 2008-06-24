

module Merb
  PROTECTED_IVARS = %w[@_new_cookie
                       @method
                       @env
                       @web_controller
                       @_body
                       @_fingerprint_before
                       @_session
                       @_headers
                       @_cookies
                       @_request
                       @_status
                       @_view_context_cache
                       @_response
                       @_params
                       @thrown_content
                       @_route
                       @_benchmarks
                       @_provided_formats
                       @_format_value
                       @_content_type
                       @_merb_unmatched
                       @_provided_formats
                       @template]

                       
  module GlobalHelper
  end    
  # The ViewContext is really just an empty container for us to fill with
  # instance variables from the controller, include helpers into and then use as
  # the context object passed to Erubis when evaluating the templates.
  class ViewContext
    include Merb::ViewContextMixin
    include Merb::WebControllerMixin
    
    def initialize(controller)
      @web_controller = controller
      @_merb_partial_locals = {}
      (@web_controller.instance_variables - PROTECTED_IVARS).each do |ivar|
        self.instance_variable_set(ivar, @web_controller.instance_variable_get(ivar))
      end
      begin
        self.class.class_eval(" include Merb::GlobalHelper; include Merb::#{@web_controller.class.name}Helper") 
      rescue NameError
        Merb.logger. debug("Missing Helper: Merb::#{@web_controller.class.name}Helper")
      end  
    end
    
    # hack so markaby doesn't dup us and lose ivars.
    def dup
      self
    end
      
    # accessor for the view. refers to the current @web_controller object
    def controller
      @web_controller
    end
  
    alias_method :old_respond_to?, :respond_to?
    
    def respond_to?(sym, include_private=false)
      old_respond_to?(sym, include_private) || @web_controller.respond_to?(sym, include_private) || @_merb_partial_locals.key?(sym)
    end
    
    # catch any method calls that the controller responds to
    # and delegate them back to the controller.
    def method_missing(sym, *args, &blk)
      if @_merb_partial_locals.key?(sym)
        @_merb_partial_locals[sym]
      else
        @web_controller.send(sym, *args, &blk)
      end
    end
    
  end
  
end
