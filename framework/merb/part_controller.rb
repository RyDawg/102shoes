module Merb
  class PartController < AbstractController
    self._template_root = File.expand_path(self._template_root / "../parts/views")
    include Merb::WebControllerMixin
    
    def initialize(web_controller)
      @web_controller = web_controller
      super
    end

    def dispatch(action=:to_s)
      old_action = params[:action]
      params[:action] = action
      super(action)
      params[:action] = old_action
      @_body
    end    
    
    private 
    
    # This method is here to overwrite the one in the general_controller mixin
    # The method ensures that when a url is generated with a hash, it contains a controller
    def get_controller_for_url_generation(opts)
       controller = opts[:controller] || @web_controller.params[:controller]
       raise "No Controller Specified for url()" unless controller
       controller
    end
  end
end    