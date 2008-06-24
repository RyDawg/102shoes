module Merb

  module RenderMixin
    @@cached_templates = {}
    include Merb::ControllerExceptions
    
    def self.included(base)
      base.class_eval {
        class_inheritable_accessor :_template_root,
                                   :_layout,
                                   :_templates,
                                   :_cached_partials
                                    
        self._layout = :application
        self._template_root = File.expand_path(Merb.view_path)
        self._templates = {}
        self._cached_partials = {}
        
        attr_accessor :template
      }
    end

    # Universal render method. Template handlers are registered
    # by template extension. So you can use the same render method
    # for any kind of template that implements an adapter module.
    #
    # Out of the box Merb supports Erubis. In addition, Haml, Markaby 
    # and Builder templates are built in, but you must activate them in
    # merb_init.rb by listing the name of the template engine you 
    # want to use:
    #
    #   Merb::Template::Haml
    #
    # In addition, you can identify the type of output with an 
    # extension in the middle of the filename. Erubis is capable of 
    # rendering any kind of text output, not just HTML.
    # This is the recommended usage.
    #
    #  index.html.erb update.js.erb feed.xml.erb
    #
    # Examples:
    #
    #   render
    #
    # Looks for views/controllername/actionname.* and renders
    # the template with the proper engine based on its file extension.
    #
    #   render :layout => :none
    #
    # Renders the current template with no layout. XMl Builder templates
    # are exempt from layout by default.
    # 
    #   render :action => 'foo'
    #
    # Renders views/controllername/foo.*
    #
    #   render :nothing => 200
    #
    # Renders nothing with a status of 200
    #
    #   render :template => 'shared/message'
    #
    # Renders views/shared/message
    #
    #   render :js => "$('some-div').toggle();"
    #
    # If the right hand side of :js => is a string then the proper
    # javascript headers will be set and the string will be returned 
    # verbatim as js.
    #
    #   render :js => :spinner
    #
    # When the rhs of :js => is a Symbol, it will be used as the 
    # action/template name so: views/controllername/spinner.js.erb
    # will be rendered as javascript
    #
    #   render :js => true
    #
    # This will just look for the current controller/action template
    # with the .js.erb extension and render it as javascript
    #
    # XML can be rendered with the same options as Javascript, but it
    # also accepts the :template option. This allows you to use any
    # template engine to render XML.
    #
    #   render :xml => @posts.to_xml
    #   render :xml => "<foo><bar>Hi!</bar></foo>"
    #
    # This will set the appropriate xml headers and render the rhs
    # of :xml => as a string. SO you can pass any xml string to this
    # to be rendered. 
    #
    #   render :xml => :hello
    #
    # Renders the hello.xrb template for the current controller.
    #
    #   render :xml => true
    #   render :xml => true, :action => "buffalo"
    #
    # Renders the buffalo.xml.builder or buffalo.xerb template for the current controller.
    #
    #   render :xml=>true, :template => 'foo/bar'
    #
    # Renders the the foo/bar template. This is not limited to
    # the default rxml, xerb, or builder templates, but could
    # just as easy be HAML.
    # 
    # Render also supports passing in an object
    # ===Example
    # 
    #   class People < Application
    #     provides :xml
    #
    #     def index
    #       @people = User.all
    #       render @people
    #     end
    #   end
    #   
    # This will first check to see if a index.xml.* template extists, if not
    # it will call @people.to_xml (as defined in the add_mime_type method) on the passed
    # in object if such a method exists for the current content_type  
    #
    # Conversely, there may be situations where you prefer to be more literal
    # such as when you desire to render a Hash, for those occasions, the
    # the following syntax exists:
    #   
    #   class People < Application
    #     provides :xml
    #
    #     def index
    #       @people = User.all
    #       render :obj => @people
    #     end
    #   end
    # 
    # When using multiple calls to render in one action, the context of the render is cached for performance reasons
    # That is, all instance variables are loaded into the view_context object only on the first call and then this is re-used.
    # What this means is that in the case where you may want to render then set some more instance variables and then call render again
    # you will want to use a clean context object.  To do this
    #
    # render :clean_context => true
    #
    # This will ensure that all instance variable are up to date in your views.
    #
    def render(*args,&blk)
      opts = (Hash === args.last) ? args.pop : {}
    
      action = opts[:action] || params[:action]
      opts[:layout] ||= _layout 
    
      choose_template_format(Merb.available_mime_types, opts)
      
      # Handles the case where render is called with an object
      if obj = args.first || opts[:obj]
        # Check for a template
        unless find_template({:action => action}.merge(opts))
          fmt = content_type
          if transform_method = Merb.mime_transform_method(fmt)
            set_response_headers fmt
            transform_args = provided_format_arguments_for(fmt)
            return case transform_args
              when Hash   then obj.send(transform_method, transform_args)
              when Array  then obj.send(transform_method, *transform_args)
              when Proc   then
                case transform_args.arity
                  when 3 then transform_args.call(obj, self, transform_method)
                  when 2 then transform_args.call(obj, self)
                  when 1 then transform_args.call(obj)
                  else transform_args.call
                end
              else obj.send(transform_method)
            end
          end  
        end
      end 
      
      case
      when status = opts[:nothing]
        return render_nothing(status)
        
      when opts[:inline]
        text = opts.delete(:inline)
        return render_inline(text, opts)
      else    
        set_response_headers @_template_format
        
        case @_format_value
        when String
          return @_format_value
        when Symbol
          if !Merb.available_mime_types.keys.include?(@_format_value) # render :js => "Some js value"
            template = find_template(:action => @_format_value)
          else
            if opts[@_format_value] == @_format_value # An edge case that lives in the specs
                                    # says that a render :js => :js should be catered for
              template = find_template(:action => @_format_value)
            else
              # when called from within an action as plain render within a respond_to block
              template = find_template(opts.merge( :action => action ))
            end
           end
        else
          if template = opts[:template]
            # render :template => "this_template"
            template = find_template( :template => template)
          else
            # a plain action render
            # def index; render; end
            template = find_template(:action => action)
          end
        end
      end
      
      unless template
        raise TemplateNotFound, "No template matched at #{unmatched}"
      end
      self.template ||= File.basename(template)

      engine = Template.engine_for(template)
      options = {
        :file => template,
        :view_context  => (opts[:clean_context] ? clean_view_context(engine) : cached_view_context(engine)),
        :opts => opts
      }
      content = engine.transform(options)
      if engine.exempt_from_layout? || opts[:layout] == :none || [:js].include?(@_template_format)
        content 
      else
        wrap_layout(content, opts)
      end
    end
    
    def set_response_headers(tmpl_fmt)
      if self.respond_to?(:headers)
        # Set the headers 
        headers['Content-Type'] = Merb.available_mime_types[tmpl_fmt].first
        
        # set any additinal headers that may be associated with the current mime type
        Merb.response_headers[tmpl_fmt].each do |key,value|
          headers[key.to_s] = value
        end
        
      end
    end

    def render_inline(text, opts)
      # Does not yet support format selection in the wrap_layout
      # Needs to get the template format need a spec for this
      # should be
      choose_template_format(Merb.available_mime_types, opts)
      
      engine = Template.engine_for_extension(opts[:extension] || 'erb')
      options = {
        :text => text,
        :view_context  => (opts[:clean_context] ? clean_view_context(engine) : cached_view_context(engine)),
        :opts => opts
      }
      content = engine.transform(options)
      if engine.exempt_from_layout? || opts[:layout] == :none
        content 
      else
        wrap_layout(content, opts)
      end
    end
    
    # does a render with no layout. Also sets the
    # content type header to text/javascript. Use
    # this when you want to render a template with 
    # .jerb extension.
    def render_js(template=nil)
      render :js => true, :action => (template || params[:action])
    end

    # renders nothing but sets the status, defaults
    # to 200. does send one ' ' space char, this is for
    # safari and flash uploaders to work.
    def render_nothing(status=200)
      @_status = status
      return " "
    end

  	# Sets the response's status to the specified value.  Use either an 
   	# integer (200, 201, 302, etc.), or a Symbol as defined in  
   	# Merb::ControllerExceptions::RESPONSE_CODES, such as :not_found, 
   	# :created or :see_other.
    def set_status(status)
      if status.kind_of?(Symbol)
        status  = Merb::ControllerExceptions::STATUS_CODES[status]
        status || raise("Can't find a response code with that name")
      end
      @_status = status
    end

    def render_no_layout(opts={})
      render opts.update({:layout => :none})
    end 
    
    # This is merb's partial render method. You name your 
    # partials _partialname.format.* , and then call it like
    # partial(:partialname).  If there is no '/' character
    # in the argument passed in it will look for the partial 
    # in the view directory that corresponds to the current
    # controller name. If you pass a string with a path in it
    # you can render partials in other view directories. So
    # if you create a views/shared directory then you can call
    # partials that live there like partial('shared/foo')
    def partial(template, opts={})
      choose_template_format(Merb.available_mime_types, {}) unless @_template_format
      template = _cached_partials["#{template}.#{@_template_format}"] ||= find_partial(template)
      unless template
        raise TemplateNotFound, "No template matched at #{unmatched}"
      end
      
      opts[:as] ||= template[(template.rindex('/_') + 2)..-1].split('.').first

      if opts[:with] # Render a collection or an object
       partial_for_collection(template, opts.delete(:with), opts)
      else # Just render a partial
       engine = Template.engine_for(template)
       render_partial(template, engine, opts || {})
      end
    end

    # +catch_content+ catches the thrown content from another template
    # So when you throw_content(:foo) {...} you can catch_content :foo
    # in another view or the layout.
    def catch_content(name)
      thrown_content[name] 
    end
    
    private

      def render_partial(template, engine, locals={})
        @_merb_partial_locals = locals
        options = {
          :file => template,
          :view_context => clean_view_context(engine),
          :opts => { :locals => locals }
        }
        engine.transform(options)
      end

      def partial_for_collection(template, collection, opts={})
        # Delete the internal keys, so that everything else is considered
        # a local declaration in the partial
        local_name = opts.delete(:as)

        engine = Template.engine_for(template)

        buffer = []

        collection = [collection].flatten
        collection.each_with_index do |object, count|
          opts.merge!({
              local_name.to_sym => object,
              :count            => count
          })
          buffer << render_partial(template, engine, opts)
        end

        buffer.join
      end
    
      # this returns a ViewContext object populated with all
      # the instance variables in your controller. This is used
      # as the view context object for the Erubis templates.
      def cached_view_context(engine=nil)
        @_view_context_cache ||= clean_view_context(engine)
      end
      
      def clean_view_context(engine=nil)
        if engine.nil?
          ::Merb::ViewContext.new(self)
        else
          engine.view_context_klass.new(self)
        end
      end
    
      def wrap_layout(content, opts={})
        @_template_format ||= choose_template_format(Merb.available_mime_types, opts)
        
        if opts[:layout] != :application
          layout_choice = find_template(:layout => opts[:layout])
        else
          if name = find_template(:layout => self.class.name.snake_case.split('::').join('/'))
            layout_choice = name
          else
            previous_glob = unmatched
            layout_choice = find_template(:layout => :application)
          end  
        end      
        unless layout_choice
          raise LayoutNotFound, "No layout matched #{unmatched}#{" or #{previous_glob}" if previous_glob}"
        end

        thrown_content[:layout] = content
        engine = Template.engine_for(layout_choice)
        options = {
          :file     => layout_choice,
          :view_context  => cached_view_context,
          :opts => opts
        }
        engine.transform(options)
      end
      
      # OPTIMIZE : combine find_template and find_partial ?
      def find_template(opts={})
        if template = opts[:template]
          path = _template_root / template
        elsif action = opts[:action]
          segment = self.class.name.snake_case.split('::').join('/')
          path = _template_root / segment / action
        elsif _layout = opts[:layout]
          path = _template_root / 'layout' / _layout
        else
          raise "called find_template without an :action or :layout"  
        end 
        glob_template(path, opts)
      end
      
      def find_partial(template, opts={})
        if template =~ /\//
          t = template.split('/')
          template = t.pop
          path = _template_root / t.join('/') / "_#{template}"
        else  
          segment = self.class.name.snake_case.split('::').join('/')
          path = _template_root  / segment / "_#{template}"
        end
        glob_template(path, opts)
      end

      # This method will return a matching template at the specified path, using the
      # template_name.format.engine convention
      def glob_template(path, opts = {})
        the_template = "#{path}.#{opts[:format] || @_template_format}"
        Merb::AbstractController._template_path_cache[the_template] || (@_merb_unmatched = (the_template + ".*"); nil)
      end
      
      # Chooses the format of the template based on the params hash or the explicit 
      # request of the developer.
      def choose_template_format(types, opts)
        opts[:format] ||= content_type
        @_template_format = (opts.keys & types.keys).first # Check for render :js => etc
        @_template_format ||= opts[:format]                                         
        @_format_value = opts[@_template_format] || opts[:format] # get the value of the option if something
                                              # like :js was used
                                              
        # need to change things to symbols so as not to stuff up part controllers
        if @_template_format.to_s == @_format_value.to_s
          @_template_format = @_template_format.to_sym
          @_format_value = @_format_value.to_sym
        end
        @_template_format
      end

      # For the benefit of error handlers, returns the most recent glob
      # pattern which didn't find a file in the filesystem
      def unmatched
        @_merb_unmatched
      end
      
  end  
end