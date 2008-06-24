module Merb
  module Caching
    
    
    # Action caching provides the ability to cache the output of individual actions.  This output will be stored using fragment caching 
    # (Merb::Caching::Fragment).  The output is stored based on a multipart key, which is comprised of the following pieces, in this order:
    # * controller
    # * action
    # * parameters  (represented as a list of parameter name/value pairs, sorted by name)
    # 
    #
    # === Examples
    #
    #  class UserController < Merb::Controller 
    #    cache_action(:show, :index) 
    # 
    #    def show 
    #       ... do some work to show a user ... 
    #    end  
    #    
    #    def index
    #       ... get the list of users ...
    #    end
    #  end 
    #
    # In this case, we would expect show to take an :id parameter, and index to take no parameters, so the fragment stored for this action 
    # will be represented thus:
    #   get :show, :id => 25    => [:user_controller, :show, :id, 25]
    #   get :index => [:user_controller, :index]
    # 
    # Action caches are expired based on the action alone (TODO: We need to modify expire action to allow expiration for specific parameter values).
    #   expire_action(:show)  => This will expire all cached show actions (i.e. All users, in this case)    
     
    module Actions 
  
      def self.included(base) # :nodoc: 

        base.extend(ClassMethods)
      end
  
      module ClassMethods
  
        # Cache the specific actions.  If those actions take parameters, then those parameters will be considered part of the key.
        # 
        def cache_action(*actions)
          before :_get_action_fragment, :only => actions        
          after :_store_action_fragment, :only => actions
        end
        
      end

      
      # Expire all cached content for the specific action, or array of actions.  
      def expire_action(*actions)
        return unless _caching_enabled?        
        for action in [actions].flatten
          ::Merb::Caching::Fragment.expire_fragment(params_key(:action => action))
        end
      end

      
      private

      def _caching_enabled?
        ::Merb::Config[:cache_templates]
      end

      def _get_action_fragment
        return unless _caching_enabled?        
        if fragment = ::Merb::Caching::Fragment.get(params_key)
          throw :halt, fragment
        end
      end
      
      def _store_action_fragment        
        return unless _caching_enabled?
        ::Merb::Caching::Fragment.put(params_key, body)
      end
      
      
      def params_key(overrides = {})
        key = []
        additional_parameters = params.clone.merge(overrides)
        key << additional_parameters.delete(:controller).to_s.snake_case        
        key << additional_parameters.delete(:action).to_s.snake_case        
        key << additional_parameters.keys.sort{|a,b| a.to_s <=> b.to_s}.collect{|k| [k.to_s, additional_parameters[k].to_s]}.flatten
        key.flatten
      end
  
    end
  end
end  