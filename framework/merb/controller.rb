module Merb
  
  # All of your web controllers will inherit from Merb::Controller. This 
  # superclass takes care of parsing the incoming headers and body into 
  # params and cookies and headers. If the request is a file upload it will
  # stream it into a tempfile and pass in the filename and tempfile object
  # to your controller via params. It also parses the ?query=string and
  # puts that into params as well.
  #
  # == Sessions
  # 
  # Session data can be accessed through the +session+ hash:
  #
  #   session[:user_id] = @user.id
  #
  # Session data is available until the user's cookie gets deleted/expires,
  # or until your specific session store expires the data.
  #
  # === Session Store
  #
  # The session store is set in Merb.root/config/merb.yml :
  #
  #   :session_store: your_store
  #
  # Out of the box merb supports three session stores
  #
  # cookie:: All data (max 4kb) stored directly in cookie.  Data integrity is checked on each request to prevent tampering. (Merb::CookieStore)
  # memory:: Data stored in a class in memory. (Merb::MemorySession)
  # mem_cache:: Data stored in mem_cache. (Merb::MemCacheSession)
  #
  # See the documentation on each session store for more information.
  #
  # You can also use a session store provided by a plugin.  For instance, if you have DataMapper you can set
  #
  #   :session_store: datamapper
  #
  # In this case session data will be stored in the database, as defined by the merb_datamapper plugin.
  # Similar functionality exists for +activerecord+ and +sequel+ currently.
  
  class Controller < AbstractController
    class_inheritable_accessor :_session_id_key, :_session_expiry
    cattr_accessor :_subclasses, :session_secret_key
    self._subclasses = []
    self.session_secret_key = nil
    self._session_id_key = '_session_id'
    self._session_expiry = Time.now + Merb::Const::WEEK * 2

    include Merb::ControllerMixin
    include Merb::ResponderMixin
    include Merb::ControllerExceptions
    include Merb::Caching::Actions
        
    class << self
      def inherited(klass)
        _subclasses << klass.to_s unless _subclasses.include?(klass.to_s)
        super
      end      
      
      def callable_actions
        @callable_actions ||= begin
          hsh = {}
          (public_instance_methods - hidden_actions).each {|action| hsh[action.to_s] = true}
          hsh
        end
      end
      
      def hidden_actions
        write_inheritable_attribute(:hidden_actions, Merb::Controller.public_instance_methods) unless read_inheritable_attribute(:hidden_actions)
        read_inheritable_attribute(:hidden_actions)
      end
      
      # Hide each of the given methods from being callable as actions.
      def hide_action(*names)
        write_inheritable_attribute(:hidden_actions, hidden_actions | names.collect { |n| n.to_s })
      end
      
      def build(request, response = StringIO.new, status=200, headers={'Content-Type' => 'text/html; charset=utf-8'})
        cont = new
        cont.set_dispatch_variables(request, response, status, headers)
        cont
      end
    end
    
    def set_dispatch_variables(request, response, status, headers)
      if request.params.key?(_session_id_key)
        if Merb::Config[:session_id_cookie_only]
          # This condition allows for certain controller/action paths to allow
          # a session ID to be passed in a query string. This is needed for
          # Flash Uploads to work since flash will not pass a Session Cookie
          # Recommend running session.regenerate after any controller taking
          # advantage of this in case someone is attempting a session fixation
          # attack
          if Merb::Config[:query_string_whitelist].include?("#{request.controller_name}/#{request.action}")
          # FIXME to use routes not controller and action names -----^
            request.cookies[_session_id_key] = request.params[_session_id_key]
          end
        else
          request.cookies[_session_id_key] = request.params[_session_id_key]
        end
      end
      @_request  = request
      @_response = response
      @_status   = status
      @_headers  = headers
    end
    
    def dispatch(action=:index)
      start = Time.now    
      if self.class.callable_actions[action.to_s]
        params[:action] ||= action
        setup_session
        super(action)
        finalize_session
      else
        raise ActionNotFound, "Action '#{action}' was not found in #{self.class}"
      end
      @_benchmarks[:action_time] = Time.now - start
      Merb.logger.info("Time spent in #{self.class}##{action} action: #{@_benchmarks[:action_time]} seconds")
    end
      
    # Accessor for @_body. Please use body and never @body directly.
    def body
       @_body  
    end
    
    # Accessor for @_status. Please use status and never @_status directly.
    def status
       @_status
    end
    
    # Accessor for @_request. Please use request and never @_request directly.
    def request
       @_request
    end
    
    def params
      request.params
    end
    
    def cookies
      @_cookies ||= Cookies.new(request.cookies, @_headers)
    end
    
    # Accessor for @_headers. Please use headers and never @_headers directly.
    def headers
      @_headers
    end
    
    # Accessor for @_session. Please use session and never @_session directly.    
    def session
      request.session
    end
    
    # Accessor for @_response. Please use response and never @_response directly.
    def response
      @_response
    end

    # Accessor for @_route. Please use route and never @_route directly.
    def route
      request.route
    end
    
    # Sends mail via a MailController (a tutorial can be found in the
    # MailController docs).
    # 
    #  send_mail FooMailer, :bar, :from => "foo@bar.com", :to => "baz@bat.com"
    # 
    # would send an email via the FooMailer's bar method.
    # 
    # The mail_params hash would be sent to the mailer, and includes items
    # like from, to subject, and cc. See
    # Merb::MailController#dispatch_and_deliver for more details.
    # 
    # The send_params hash would be sent to the MailController, and is
    # available to methods in the MailController as <tt>params</tt>. If you do
    # not send any send_params, this controller's params will be available to
    # the MailController as <tt>params</tt>
    def send_mail(klass, method, mail_params, send_params = nil)
      klass.new(send_params || params, self).dispatch_and_deliver(method, mail_params)
    end
    
    # Dispatches a PartController. Use like:
    # 
    #   <%= part TodoPart => :list %>
    #
    # will instantiate a new TodoPart controller and call the :list action
    # invoking the Part's before and after filters as part of the call.
    #
    # returns a string containing the results of the Part controllers dispatch
    #
    # You can compose parts easily as well, these two parts will stil be wrapped
    # in the layout of the Foo controller:
    #
    # class Foo < Application
    #   def some_action
    #     wrap_layout(part(TodoPart => :new) + part(TodoPart => :list))
    #   end
    # end
    #
    def part(opts={})
      res = opts.inject([]) do |memo,(klass,action)|
        memo << klass.new(self).dispatch(action)
      end
      res.size == 1 ? res[0] : res
    end
    
    private
    
    # This method is here to overwrite the one in the general_controller mixin
    # The method ensures that when a url is generated with a hash, it contains a controller
    def get_controller_for_url_generation(options)
      controller = options[:controller] || params[:controller]
      controller = params[:controller] if controller == :current
      controller
    end
    
  end  
  
end
