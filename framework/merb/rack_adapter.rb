module Merb
  module Rack
    
    class RequestWrapper
      def initialize(env)
        @env = env
      end
      
      def params
        @env
      end
      
      def body
        @env['rack.input']
      end
    end
      
    class Adapter
      def call(env)
        env["PATH_INFO"] ||= ""
        env["SCRIPT_NAME"] ||= ""
        if env["REQUEST_URI"] =~ %r{(https?://)[^/](.*)}
          env["REQUEST_URI"] = $2
        end  
        request = RequestWrapper.new(env)
        response = StringIO.new
        begin
          controller, action = ::Merb::Dispatcher.handle(request, response)
        rescue Object => e
          return [500, {"Content-Type"=>"text/html"}, "Internal Server Error"]
        end
        
        [controller.status, controller.headers, controller.body]
      end
    end
  end
end
