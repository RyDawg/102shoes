  require 'enumerator'

module Merb
  class << self
    # Provides the currently implemented mime types as a hash
    def available_mime_types
      ResponderMixin::Rest::TYPES
    end
    
    # Any specific outgoing headers should be included here.  These are not
    # the content-type header but anything in addition to it.
    # +tranform_method+ should be set to a symbol of the method used to
    # transform a resource into this mime type.
    # For example for the :xml mime type an object might be transformed by
    # calling :to_xml, or for the :js mime type, :to_json.
    # If there is no transform method, use nil.
    def add_mime_type(key,transform_method, values,new_response_headers = {})
      raise ArgumentError unless key.is_a?(Symbol) && values.is_a?(Array)
      ResponderMixin::Rest::TYPES.update(key => values)
      add_response_headers!(key, new_response_headers)   
      ResponderMixin::Rest::TRANSFORM_METHODS.merge!(key => transform_method)
    end    
    
    def remove_mime_type(key)
      key == :all ? false : ResponderMixin::Rest::TYPES.delete(key)
    end
    
    # Return the method name (if any) for the mimetype
    def mime_transform_method(key)
      ResponderMixin::Rest::TRANSFORM_METHODS[key]
    end
    
    # Return default arguments for transform method (if any)
    def mime_transform_method_defaults(key)
      ResponderMixin::Rest::TRANSFORM_METHOD_DEFAULTS[key]
    end
    
    # Set default arguments/proc for a format transform method
    def set_mime_transform_method_defaults(key, *args, &block)
      raise "Unknown mimetype #{key}" unless ResponderMixin::Rest::TRANSFORM_METHODS[key]
      args = block if block_given?
      ResponderMixin::Rest::TRANSFORM_METHOD_DEFAULTS[key] = args unless args.empty?
    end
    
    # Adds outgoing headers to a mime type.  This can be done with the Merb.add_mime_type method
    # or directly here.  
    # ===Example
    # {{[
    #   Merb.outgoing_headers!(:xml => { :Encoding => "UTF-8" })
    # ]}}
    #
    # This method is destructive on any already defined outgoing headers
    def add_response_headers!(key, values = {})
      raise ArgumentError unless key.is_a?(Symbol) && values.is_a?(Hash)
      response_headers[key] = values
    end
    
    def response_headers
      ResponderMixin::Rest::RESPONSE_HEADERS
    end
    
    # Completely removes any headers set that are additional to the content-type header.
    def remove_response_headers!(key)
      raise ArgumentError unless key.is_a?(Symbol)
      response_headers[key] = {}
    end
    
    # Sets the mime types and outgoing headers to their original states
    def reset_default_mime_types!
      available_mime_types.clear
      response_headers.clear
      Merb.add_mime_type(:all,nil,%w[*/*])
      Merb.add_mime_type(:yaml,:to_yaml,%w[application/x-yaml text/yaml])
      Merb.add_mime_type(:text,:to_text,%w[text/plain])
      Merb.add_mime_type(:html,nil,%w[text/html application/xhtml+xml application/html])
      Merb.add_mime_type(:xml,:to_xml,%w[application/xml text/xml application/x-xml], :Encoding => "UTF-8")
      Merb.add_mime_type(:js,:to_json,%w[ text/javascript  application/javascript application/x-javascript])
      Merb.add_mime_type(:json,:to_json,%w[application/json  text/x-json  ])
    end
  
  end

  # The ResponderMixin adds methods that help you manage what
  # formats your controllers have available, determine what format(s)
  # the client requested and is capable of handling, and perform
  # content negotiation to pick the proper content format to
  # deliver.
  # 
  # If you hear someone say "Use provides" they're talking about the
  # Responder.  If you hear someone ask "What happened to respond_to?"
  # it was replaced by provides and the other Responder methods.
  # 
  # == A simple example
  # 
  # The best way to understand how all of these pieces fit together is
  # with an example.  Here's a simple web-service ready resource that
  # provides a list of all the widgets we know about.  The widget list is 
  # available in 3 formats: :html (the default), plus :xml and :text.
  # 
  #     class Widgets < Application
  #       provides :html   # This is the default, but you can
  #                        # be explicit if you like.
  #       provides :xml, :text
  #       
  #       def index
  #         @widgets = Widget.fetch
  #         render @widgets
  #       end
  #     end
  # 
  # Let's look at some example requests for this list of widgets.  We'll
  # assume they're all GET requests, but that's only to make the examples
  # easier; this works for the full set of RESTful methods.
  # 
  # 1. The simplest case, /widgets.html
  #    Since the request includes a specific format (.html) we know
  #    what format to return.  Since :html is in our list of provided
  #    formats, that's what we'll return.  +render+ will look
  #    for an index.html.erb (or another template format
  #    like index.html.mab; see the documentation on Template engines)
  # 
  # 2. Almost as simple, /widgets.xml
  #    This is very similar.  They want :xml, we have :xml, so
  #    that's what they get.  If +render+ doesn't find an 
  #    index.xml.builder or similar template, it will call +to_xml+
  #    on @widgets.  This may or may not do something useful, but you can 
  #    see how it works.
  #
  # 3. A browser request for /widgets
  #    This time the URL doesn't say what format is being requested, so
  #    we'll look to the HTTP Accept: header.  If it's '*/*' (anything),
  #    we'll use the first format on our list, :html by default.
  #    
  #    If it parses to a list of accepted formats, we'll look through 
  #    them, in order, until we find one we have available.  If we find
  #    one, we'll use that.  Otherwise, we can't fulfill the request: 
  #    they asked for a format we don't have.  So we raise
  #    406: Not Acceptable.
  # 
  # == A more complex example
  # 
  # Sometimes you don't have the same code to handle each available 
  # format. Sometimes you need to load different data to serve
  # /widgets.xml versus /widgets.txt.  In that case, you can use
  # +content_type+ to determine what format will be delivered.
  # 
  #     class Widgets < Application
  #       def action1
  #         if content_type == :text
  #           Widget.load_text_formatted(params[:id])
  #         else
  #           render
  #         end
  #       end
  #       
  #       def action2
  #         case content_type
  #         when :html
  #           handle_html()
  #         when :xml
  #           handle_xml()
  #         when :text
  #           handle_text()
  #         else
  #           render
  #         end
  #       end
  #     end
  # 
  # You can do any standard Ruby flow control using +content_type+.  If
  # you don't call it yourself, it will be called (triggering content
  # negotiation) by +render+.
  #
  # Once +content_type+ has been called, the output format is frozen,
  # and none of the provides methods can be used.
  module ResponderMixin
    
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.class_eval do
        class_inheritable_accessor :class_provided_formats
        class_inheritable_accessor :class_provided_format_arguments
      end
      base.reset_provides
    end

    module ClassMethods

      # Adds symbols representing formats to the controller's
      # default list of provided_formats.  These will apply to
      # every action in the controller, unless modified in the action.
      # If the last argument is a Hash or an Array, these are regarded
      # as arguments to pass to the to_<mime_type> method as needed.
      def provides(*formats, &block)
        options = extract_provides_options(formats, &block)
        formats.each do |fmt|
          self.class_provided_formats << fmt unless class_provided_formats.include?(fmt)
          self.class_provided_format_arguments[fmt] = options unless options.nil?
        end
      end
      
      # Overwrites the controller's list of provided_formats. These
      # will apply to every action in the controller, unless modified
      # in the action.
      def only_provides(*formats)
        clear_provides
        provides(*formats)
      end
      
      # Removes formats from the controller's
      # default list of provided_formats. These will apply to
      # every action in the controller, unless modified in the action.
      def does_not_provide(*formats)
        self.class_provided_formats -= formats
        formats.each { |fmt| self.class_provided_format_arguments.delete(fmt) }
      end
      
      # Clear any formats and their options
      def clear_provides
        self.class_provided_formats = []
        self.class_provided_format_arguments = {}
      end
      
      # Reset to the default list of formats
      def reset_provides
        only_provides(:html)
      end
      
      # Extract arguments for provided format methods
      def extract_provides_options(args, &block)
        return block if block_given?
        case args.last
          when Hash   then [args.pop]
          when Array  then args.pop
          when Proc   then args.pop
          else nil
        end
      end
            
    end
    
    # Returns the current list of formats provided for this instance
    # of the controller.  It starts with what has been set in the controller
    # (or :html by default) but can be modifed on a per-action basis.
    def provided_formats
      @_provided_formats ||= class_provided_formats.dup
    end
    
    # Sets the provided formats for this action.  Usually, you would
    # use a combination of +provides+, +only_provides+ and +does_not_provide+
    # to manage this, but you can set it directly.
    # If the last argument is a Hash or an Array, these are regarded
    # as arguments to pass to the to_<mime_type> method as needed. 
    def set_provided_formats(*formats, &block)
      raise_if_content_type_already_set!
      @_provided_formats = []
      @_provided_format_arguments = {}
      provides(*formats.flatten, &block)
    end
    alias :provided_formats= :set_provided_formats
    
    # Returns a Hash of arguments for format methods
    def provided_format_arguments
      @_provided_format_arguments ||= Hash.new.replace(class_provided_format_arguments)
    end
    
    # Returns the arguments (if any) for the mime_transform_method call
    def provided_format_arguments_for(fmt)
      self.provided_format_arguments[fmt] || Merb.mime_transform_method_defaults(fmt)
    end
    
    # Adds formats to the list of provided formats for this particular 
    # request.  Usually used to add formats to a single action.  See also
    # the controller-level provides that affects all actions in a controller.
    def provides(*formats, &block)
      raise_if_content_type_already_set!
      options = self.class.extract_provides_options(formats, &block)
      formats.each do |fmt|
        self.provided_formats << fmt unless provided_formats.include?(fmt)
        self.provided_format_arguments[fmt] = options unless options.nil?
      end
    end
    
    # Sets list of provided formats for this particular 
    # request.  Usually used to limit formats to a single action.  See also
    # the controller-level provides that affects all actions in a controller.
    def only_provides(*formats)
      self.set_provided_formats(*formats)
    end
    
    # Removes formats from the list of provided formats for this particular 
    # request.  Usually used to remove formats from a single action.  See
    # also the controller-level provides that affects all actions in a
    # controller.
    def does_not_provide(*formats)
      formats.flatten!
      self.provided_formats -= formats
      formats.each { |fmt| self.provided_format_arguments.delete(fmt) }
    end
    
    # Do the content negotiation:
    # 1. if params[:format] is there, and provided, use it
    # 2. Parse the Accept header
    # 3. If it's */*, use the first provided format
    # 4. Look for one that is provided, in order of request
    # 5. Raise 406 if none found
    def perform_content_negotiation # :nodoc:
      raise Merb::ControllerExceptions::NotAcceptable if provided_formats.empty?
      if fmt = params[:format]
        if provided_formats.include?(fmt.to_sym)
          fmt.to_sym
        else
          raise Merb::ControllerExceptions::NotAcceptable
        end
      else
        accepts = Rest::Responder.parse(request.accept).
          collect {|t| t.to_sym}
        if accepts.include?(:all)
          provided_formats.first
        else
          accepts.each do |type|
            return type if provided_formats.include?(type)
          end
          raise Merb::ControllerExceptions::NotAcceptable
        end
      end
    end
    
    # Checks to see if content negotiation has already been performed.
    # If it has, you can no longer modify the list of provided formats.
    def content_type_set?
      !@_content_type.nil?
    end
    
    # Returns the output format for this request, based on the 
    # provided formats, <tt>params[:format]</tt> and the client's HTTP
    # Accept header.
    #
    # The first time this is called, it triggers content negotiation
    # and caches the value.  Once you call +content_type+ you can
    # not set or change the list of provided formats.
    #
    # Called automatically by +render+, so you should only call it if
    # you need the value, not to trigger content negotiation. 
    def content_type
      unless content_type_set?
        @_content_type = perform_content_negotiation
        raise Merb::ControllerExceptions::NotAcceptable.new("Unknown content_type for response: #{@_content_type}") unless
          Merb.available_mime_types.has_key?(@_content_type)
        headers['Content-Type'] = Merb.available_mime_types[@_content_type].first
      end
      @_content_type
    end
    
    # Sets the output content_type for this request.  Normally you
    # should use +provides+, +does_not_provide+ and +only_provides+
    # and then let the content negotiation process determine the proper
    # content_type.  However, in some circumstances you may want to
    # set it directly, or override what content negotiation picks.
    def content_type=(new_type)
      @_content_type = new_type
    end

    private
    
    def raise_if_content_type_already_set!
      raise "Cannot modify provided_formats because content_type has already been set" if content_type_set?
    end

    module Rest
      
      TYPES = {}
      RESPONSE_HEADERS = Hash.new([])
      TRANSFORM_METHODS = {}
      TRANSFORM_METHOD_DEFAULTS = {}

      class Responder
      
        protected
          
          def self.parse(accept_header)
            # parse the raw accept header into a unique, sorted array of AcceptType objects
            list = accept_header.to_s.split(/,/).enum_for(:each_with_index).map do |entry,index|
              AcceptType.new(entry,index += 1)
            end.sort.uniq
            # firefox (and possibly other browsers) send broken default accept headers.
            # fix them up by sorting alternate xml forms (namely application/xhtml+xml)
            # ahead of pure xml types (application/xml,text/xml).
            if app_xml = list.detect{|e| e.super_range == 'application/xml'}
              list.select{|e| e.to_s =~ /\+xml/}.each { |acc_type|
                list[list.index(acc_type)],list[list.index(app_xml)] = 
                  list[list.index(app_xml)],list[list.index(acc_type)] }
            end
            list
          end
          
      end

      class AcceptType

        attr_reader :media_range, :quality, :index, :type, :sub_type
        
        def initialize(entry,index)
          @index = index
          @media_range, quality = entry.split(/;\s*q=/).map{|a| a.strip }
          @type, @sub_type = @media_range.split(/\//)
          quality ||= 0.0 if @media_range == '*/*'
          @quality = ((quality || 1.0).to_f * 100).to_i
        end
      
        def <=>(entry)
          c = entry.quality <=> quality
          c = index <=> entry.index if c == 0
          c
        end
      
        def eql?(entry)
          synonyms.include?(entry.media_range)
        end
      
        def ==(entry); eql?(entry); end
      
        def hash; super_range.hash; end
      
        def synonyms
          @syns ||= TYPES.values.select{|e| e.include?(@media_range)}.flatten
        end
      
        def super_range
          synonyms.first || @media_range
        end
      
        def to_sym
          TYPES.select{|k,v| 
            v == synonyms || v[0] == synonyms[0]}.flatten.first
        end
      
        def to_s
          @media_range
        end
      
      end
      
    end

  end
  reset_default_mime_types!
  
end