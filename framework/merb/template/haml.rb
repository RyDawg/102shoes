begin
  require 'haml/engine'
rescue LoadError
  puts "you must install the haml gem to use .haml templates"
end
require File.join( File.dirname(__FILE__), "..", "template")

module Haml
  module Helpers
    
    def _buffer( binding )
      @_buffer = eval( "_erbout", binding )
    end

    alias_method :capture, :capture_haml

  end
end

module Merb
  module Template
    
    class HamlViewContext < ViewContext
      include ::Merb::InlinePartialMixin
    end
    
    module Haml
      
      class << self
        
        @@hamls ||= {}
        @@mtimes ||= {}
        
        def exempt_from_layout?
          false    
        end
        
        def transform(options = {})
          opts, text, file, view_context = options.values_at(:opts, :text, :file, :view_context)
          
          begin 

            # Merb handles the locals
            opts.delete(:locals)
            
            template = text ? text : load_template(file)
            
            haml = ::Haml::Engine.new(template, opts)  
            haml.to_html(view_context) 
          rescue 
            # ::Haml::Engine often inserts a bogus "(haml):#{line_number}" entry in the backtrace. 
            # Let's replace it with the path of the actual template 
            $@[0].sub! /\(haml\)/, file  
            raise # Raise the exception again
          end
        end
        
        def view_context_klass
          HamlViewContext
        end
      
        private
          def load_template(file)
            template = ""
            if @@hamls[file] && !cache_template?(file)
              template = @@hamls[file]
            else  
              template = IO.read(file)
              if cache_template?(file)
                @@hamls[file], @@mtimes[file] = template, Time.now
              end
              return template
            end
          end
        
          def cache_template?(path)
            return false unless ::Merb::Config[:cache_templates]
            return true unless @@hamls[path]
            @@mtimes[path] < File.mtime(path) ||
              (File.symlink?(path) && (@@mtimes[path] < File.lstat(path).mtime))
          end
        
      end
      
    end
  end
end
