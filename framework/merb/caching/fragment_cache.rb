module Merb
  module Caching
    module Fragment
      class << self
        def cache
          @cache ||= determine_cache_store
        end
        
        def clear
          cache.clear
          @cache = nil
        end
        
        def get(name)
          cache.get(name)
        end
        
        def put(name, content = nil)          
          cache.put(name, content)
          content
        end
        
        def expire_fragment(name)
          cache.delete(name)
        end
        
        def determine_cache_store
          if ::Merb::Config[:cache_store].to_s == "file"
            require 'merb/caching/store/file_cache'
            ::Merb::Caching::Store::FileCache.new
          else
            require 'merb/caching/store/memory_cache'
            ::Merb::Caching::Store::MemoryCache.new
          end
        end  
      end
    end
  end
end