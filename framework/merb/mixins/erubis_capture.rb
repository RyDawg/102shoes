module Merb
  
  

  module ErubisCaptureMixin
    
    # Provides direct acccess to the buffer for this view context
    def _buffer( the_binding )
      @_buffer = eval( "_buf", the_binding )
    end
    
    # Capture allows you to extract a part of the template into an 
    # instance variable. You can use this instance variable anywhere
    # in your templates and even in your layout. 
    # 
    # Example of capture being used in a .herb page:
    # 
    #   <% @foo = capture do %>
    #     <p>Some Foo content!</p> 
    #   <% end %>
    def capture(*args, &block)
      # execute the block
      begin
        buffer = _buffer( block.binding )
      rescue
        buffer = nil
      end
      
      if buffer.nil?
        capture_block(*args, &block)
      else
        capture_erb_with_buffer(buffer, *args, &block)
      end
    end
        
    private
      def capture_block(*args, &block)
        block.call(*args)
      end
    
      def capture_erb(*args, &block)
        buffer = _buffer
        capture_erb_with_buffer(buffer, *args, &block)
      end
    
      def capture_erb_with_buffer(buffer, *args, &block)
        pos = buffer.length
        block.call(*args)
      
        # extract the block 
        data = buffer[pos..-1]
      
        # replace it in the original with empty string
        buffer[pos..-1] = ''
      
        data
      end
    
      def erb_content_for(name, &block)
        controller.thrown_content[name] << capture_erb( &block )
      end
    
      def block_content_for(name, &block)
        controller.thrown_content[name] << capture_block( &block )
      end
  end
  
end