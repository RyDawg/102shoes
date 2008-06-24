# Used by secondary actions (a PartsController or the view)
# to provide the standard objects associated with each request.

module Merb
  module WebControllerMixin #:nodoc:
    
    def request
       @web_controller.request  
    end
            
    def params
      @web_controller.params
    end  
    
    def cookies
      @web_controller.cookies
    end  

    def headers
      @web_controller.headers
    end
    
    def session
      @web_controller.session
    end

    def response
      @web_controller.response
    end    
    
    def route
      request.route
    end
     
  end
end