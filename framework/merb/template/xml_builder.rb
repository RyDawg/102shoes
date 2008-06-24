begin
  require 'builder'
rescue LoadError
  puts "you must install the builder gem to use .rxml templates"
end

module Merb
  
  module Template # :nodoc:
    # A module to allow you to use Builder["http://builder.rubyforge.org/"] templates in your Merb applications.
    # Your Builder templates must end in .rxml, .xerb, or .builder for Merb to use them.
    
    
    
    module XMLBuilder
        
      class << self

        def exempt_from_layout? # :nodoc:
          true    
        end

        # Main method to run the Builder template.
        # 
        # In Builder's case, it sets the content type and encoding, 
        # executes the Builder template by feeding it to <tt>Builder::XmlMarkup.new</tt>, 
        # then calls <tt>target!</tt> on the<tt>Builder::XmlMarkup</tt> instance to get its XML output.   
        def transform(options = {})
          opts, text, file, view_context = options.values_at(:opts, :text, :file, :view_context)
          xml_body = text ? text : IO.read(file) 
          view_context.headers['Content-Type'] ||= 'application/xml'
          view_context.headers['Encoding']     = 'UTF-8'
          view_context.instance_eval %{
            xml = Builder::XmlMarkup.new :indent => 2
            xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
            #{xml_body}
            return xml.target!
          }
        end

        def view_context_klass
          ::Merb::ViewContext
        end
      end
      
    end
        
  end
    
end