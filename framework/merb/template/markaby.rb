begin
  require 'markaby'
rescue LoadError
  puts "you must install the markaby gem to use .mab templates"
end
  
module Markaby  
  class Builder
    def _buffer( binding )
      eval( "_erbout", binding )
    end
    
    def concat( string, binding )
      _buffer( binding ) << string
    end
  end
end
  
module Merb
  
  module Template  
    module Markaby    
      class << self

        def exempt_from_layout?
          false    
        end
        
        # OPTIMIZE :  add mab template caching. what does this mean for mab? 
        # mab is just ruby, there's no two phase compile and run
        def transform(options = {})
          opts, text, file, view_context = options.values_at(:opts, :text, :file, :view_context)
          
          if opts[:locals]
            locals = ""
            opts[:locals].keys.each do |key|
              locals << "#{key} = @_merb_partial_locals[:#{key}]\n"
            end
            locals
          end
          
          template = text ? text : File.read(file)
          mab = ::Markaby::Builder.new({}, view_context) {
            instance_eval("#{locals}#{template}")
          }
          mab.to_s
        end
        
        def view_context_klass
          ::Merb::ViewContext
        end
        
      end
      
    end
        
  end
    
end
