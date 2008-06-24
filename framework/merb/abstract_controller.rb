module Merb
  
  class AbstractController                 
    include Merb::RenderMixin
    include Merb::GeneralControllerMixin
    
    class_inheritable_accessor :before_filters
    class_inheritable_accessor :after_filters
    class_inheritable_accessor :action_argument_list    
    self.action_argument_list = Hash.new([])
    
    cattr_accessor :_abstract_subclasses
    cattr_accessor :_template_path_cache
    self._abstract_subclasses = []
    self._template_path_cache
    
    class << self
      def inherited(klass)
        _abstract_subclasses << klass.to_s unless _abstract_subclasses.include?(klass.to_s)
        super
      end
    end    
    
    # Holds internal execution times. Prefaced with an underscore to not 
    # conflict with user-defined controller instance variables.
    attr_accessor :_benchmarks, :thrown_content
    
    def initialize(*args)
      @_benchmarks = {}
      @thrown_content = AbstractController.default_thrown_content
    end
    
    def dispatch(action=:to_s)
      caught = catch(:halt) do
        start = Time.now
        result = call_filters(before_filters)
        @_benchmarks[:before_filters_time] = Time.now - start if before_filters
        result
      end
    
      @_body = case caught
      when :filter_chain_completed
        call_action(action)
      when String
        caught
      when nil
        filters_halted
      when Symbol
        send(caught)
      when Proc
        caught.call(self)  
      else
        raise MerbControllerError, "The before filter chain is broken dude. wtf?"
      end
      start = Time.now
      call_filters(after_filters) 
      @_benchmarks[:after_filters_time] = Time.now - start if after_filters
    end
    
    
    # Adds the a template path to the template path cache. This is required for
    # any view templates or layouts to be found during renering.
    #
    # ==== Parameters
    # template_path<String>:: Full path to the template file.
    #
    # ==== Returns
    # Boolean:: true unless the template path is less than three levels deep.
    #
    # ==== Examples
    #   Merb::AbstractController.add_path_to_template_cache('/full/path/to/template.html.erb')
    #
    def self.add_path_to_template_cache(template_path)
      arry = template_path.split("/").last.split(".")
      return false if template_path == "" || arry.size != 3
      key = template_path.split(".")[0..-2].join(".")
      self._template_path_cache[key] = template_path
    end
    
    # Resets the template_path_cache to an empty hash
    #
    def self.reset_template_path_cache!
      self._template_path_cache = {}
    end
    
  protected
    
    def call_action(action)
      # [[:id], [:foo, 7]]
      args = self.class.action_argument_list[action.to_sym].map do |arg_default|
        arg = arg_default[0]
        raise BadRequest unless params.key?(arg.to_sym) || (arg_default.size == 2)
        params.key?(arg.to_sym) ? params[arg.to_sym] : arg_default[1]
      end rescue []
      send(action, *args)
    end
    
    # Calls a filter chain according to rules.
    #
    # ==== Parameters
    # filter_set<Array>:: Array of filter-rule pairs as two piece arrays.
    #
    # ==== Returns
    # Symbol:: :filter_chain_completed to signify execution is completed.
    #
    def call_filters(filter_set)
      (filter_set || []).each do |(filter, rule)|
        ok = false
        if rule.has_key?(:only)
          if rule[:only].include?(params[:action].intern)
            ok = true
          end
        elsif rule.has_key?(:exclude)
          if !rule[:exclude].include?(params[:action].intern)
            ok = true
          end 
        else
          ok = true
        end    
        if ok
          case filter
            when Symbol, String
             send(filter)
            when Proc
             filter.call(self)
          end
        end   
      end
      return :filter_chain_completed
    end 
    
    # +finalize_session+ is called at the end of a request to finalize/store
    # any data placed in the session. Mixins/Classes wishing to define a new
    # session store must implement this method. See merb/lib/sessions/*
    # for examples of built in session stores.
    def finalize_session #:nodoc:
      # noop
    end  

    # +setup_session+ is called at the beginning of a request to load the
    # current session data. Mixins/Classes wishing to define a new session
    # store must implement this method. See merb/lib/sessions/* for examples
    # of built in session stores.
    def setup_session #:nodoc:
      # noop
    end
    
    # Override this method on your controller classes to specialize
    # the output when the filter chain is halted.
    #
    # ==== Returns
    # String:: A message explaining what happened.
    #
    def filters_halted
      "<html><body><h1>Filter Chain Halted!</h1></body></html>"  
    end
    
    
    # Specify before filters in your controllers. If a method name is given
    # that method will be called and if a proc is given it will be called
    # with an argument of self where self is the current controller object.
    # When you use a proc as a filter it needs to take one parameter.
    # 
    # Merb's before filter chain is very flexible. To halt the filter chain you
    # use throw :halt. If throw is called with only one argument of :halt the
    # return of the method filters_halted will be what is rendered to the view.
    # You can overide filters_halted in your own controllers to control what it
    # outputs. But the throw construct is much more powerful then just that.
    # throw :halt can also take a second argument. Here is what that second arg
    # can be and the behavior each type can have:
    #
    # * String:
    #   when the second arg is a string then that string will be what
    #   is rendered to the browser. Since merb's render method returns
    #   a string you can render a template or just use a plain string:
    #
    #     throw :halt, "You don't have permissions to do that!"
    #     throw :halt, render(:action => :access_denied)
    #
    # * Symbol:
    #   If the second arg is a symbol then the method named after that
    #   symbol will be called
    #
    #   throw :halt, :must_click_disclaimer
    #
    # * Proc:
    #
    #   If the second arg is a Proc, it will be called and its return
    #   value will be what is rendered to the browser:
    #
    #     throw :halt, Proc.new {|c| c.access_denied }
    #     throw :halt, Proc.new {|c| Tidy.new(c.index) }
    #
    # ==== Parameters
    # filter<Symbol, String, Proc>:: The filter to be added.
    # opts<Hash>::
    #   The options for the filter to be added (see below). Defaults to an
    #   empty Hash.
    #
    # ==== Options (opts)
    # :only<Array, Symbol>:: The actions that the filter should be applied to.
    # :exclude<Array, Symbol>:: The actions that should ignore this filter.
    #
    # Note: :only and :exluce cannot be used simultaneously.
    #
    # ==== Examples
    #   before :some_filter
    #   before :authenticate, :exclude => [:login, :signup]
    #   before Proc.new {|c| c.some_method }, :only => :foo
    #
    def self.before(filter, opts={})
      add_filter((self.before_filters ||= []), filter, opts)
    end
    
    # Specify after filters in your controllers. If a method name is given
    # that method will be called and if a proc is given it will be called
    # with an argument of self where self is the current controller object.
    # When you use a proc as a filter it needs to take one parameter.
    #
    # ==== Parameters
    # filter<Symbol, String, Proc>:: The filter to be added.
    # opts<Hash>::
    #   The options for the filter to be added (see below). Defaults to an
    #   empty Hash.
    #
    # ==== Options (opts)
    # :only<Array, Symbol>:: The actions that the filter should be applied to.
    # :exclude<Array, Symbol>:: The actions that should ignore this filter.
    #
    # Note: :only and :exluce cannot be used simultaneously.
    #
    # ==== Examples
    #   after :some_filter
    #   after :tidy, :exclude => [:stats]
    #   before Proc.new {|c| c.some_method }, :only => :foo
    #
    def self.after(filter, opts={})
      add_filter((self.after_filters ||= []), filter, opts)
    end
    
    # Remove an already declared before filter from your controller.
    #
    # ==== Parameters
    # filter<String, Symbol>:: The filter to be removed.
    #
    # ==== Examples
    #   class Application < Merb::Controller
    #     before :require_login
    #   end
    #
    #   class Login < Application
    #     skip_before :require_login  # Login should be accessible by everyone
    #   end
    #
    def self.skip_before(filter)
      skip_filter((self.before_filters || []), filter)
    end
    
    # Remove an already declared after filter from your controller.
    #
    # ==== Parameters
    # filter<String, Symbol>:: The filter to be removed.
    #
    # ==== Examples
    #   class Application < Merb::Controller
    #     after :log_activitiy
    #   end
    #
    #   class Stats < Application
    #     skip_after :log_activitiy
    #   end
    #
    def self.skip_after(filter)
      skip_filter((self.after_filters || []), filter)
    end
    
    def self.default_thrown_content
      Hash.new{ |hash, key| hash[key] = "" }
    end
    
    # Set here to respond when rendering to cover the provides syntax of
    # setting the content_type
    # 
    # ==== Returns
    # Boolean:: True if the content type was set.
    #
    def content_type_set?
      false
    end

    # Returns the content type.
    #
    # ==== Returns
    # Symbol:: The content type.
    #
    def content_type
      params[:format] || :html
    end

  private

    # Adds a filter to a list of filters.
    #
    # ==== Parameters
    # filters<Array>::
    #   The array of filters to which the filter should be added.
    # filter<Symbol, String, Proc>:: The filter to be added.
    # opts<Hash>::
    #   The options for the filter to be added (see below). Defaults to an
    #   empty Hash.
    #
    # ==== Options (opts)
    # :only<Array, Symbol>:: The actions that the filter should be applied to.
    # :exclude<Array, Symbol>:: The actions that should ignore this filter.
    #
    # ==== Raises
    # ArgumentError::
    #   The options include both the :only and the :exclude key or the filter
    #   is not a Symbol, String or Proc.
    #
    # ==== Examples
    #   add_filter([ :log_activity ], :login_required)
    #
    #   add_filter([ :log_activity ], :login_required, { :exclude => :login })
    #
    def self.add_filter(filters, filter, opts={})
      raise(ArgumentError,
        "You can specify either :only or :exclude but 
         not both at the same time for the same filter."
      ) if opts.has_key?(:only) && opts.has_key?(:exclude)
  
      opts = shuffle_filters!(opts)
    
      case filter
      when Symbol, Proc, String
        if existing_filter = filters.find {|f| f.first.to_s[filter.to_s]}
          existing_filter.last.replace(opts)
        else
          filters << [filter, opts]
        end
      else
        raise(ArgumentError, 
          'Filters need to be either a Symbol, String or a Proc'
        )        
      end
    end

    # Removes a filter from a list of filters.
    #
    # ==== Parameters
    # filters<Array>::
    #   The array of filters from which the filter should be removed.
    # filter<Symbol, String>:: The filter to be removed.
    #
    # ==== Raises
    # ArgumentError:: The filter argument is not a String or a Symbol.
    #
    # ==== Examples
    #   skip_filter([ :login_required, :log_activity ], :login_required)
    #
    def self.skip_filter(filters, filter)
      raise(ArgumentError, 
        'You can only skip filters that have a String or Symbol name.'
      ) unless [Symbol, String].include? filter.class

      Merb.logger.warn("Filter #{filter} was not found in your filter chain."
      ) unless filters.reject! {|f| f.first.to_s[filter.to_s] }
    end

    # Changes filter options hash values for the only and exclude keys to
    # arrays, if they are not arrays already.
    #
    # ==== Parameters
    # opts<Hash>:: The filter options hash. Will default to an empty Hash.
    #
    # ==== Options (opts)
    # :only<Array, Symbol>:: The actions that the filter should be applied to.
    # :exclude<Array, Symbol>:: The actions that should ignore this filter.
    #
    # ==== Returns
    # Hash:: The original options with the only and exclude values as arrays.
    #
    # ==== Examples
    #   shuffle_filters!(:only => :new)
    #   # => { :only => [:new] }
    #
    def self.shuffle_filters!(opts={})
      if opts[:only] && opts[:only].is_a?(Symbol)
        opts[:only] = [opts[:only]]
      end 
      if opts[:exclude] && opts[:exclude].is_a?(Symbol)
        opts[:exclude] = [opts[:exclude]]
      end
      return opts
    end
    
  end  
  
end