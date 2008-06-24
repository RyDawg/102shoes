module Merb
  module Caching
    module Store
      
      class MemoryCache
      
        def initialize(opts={})
          @opts = opts
          @cache = Hash.new
          @timestamps = Hash.new
          @mutex = Mutex.new
          @cache_ttl = @opts.fetch(:session_ttl, 30*60) # default 30 minutes
        end
        
        def [](key)
          key = [key].flatten.collect{|k| k.to_s}
          @mutex.synchronize {
            @timestamps[key] = Time.now
            sub_cache = @cache
            key[0..-2].each do |subkey|
              sub_cache = (sub_cache[subkey] ||= {})
            end
            sub_cache[key[-1]]
          }
        end
        alias_method :get, :[]
        alias_method :read, :[]
         
        def []=(key, val)     
          key = [key].flatten.collect{|k| k.to_s}
          @mutex.synchronize {
            sub_cache = @cache
            key[0..-2].each do |subkey|
              sub_cache = (sub_cache[subkey] ||= {})
            end
            sub_cache[key[-1]] = val
            @timestamps[key] = Time.now
          } 
        end
        alias_method :put, :[]=
        alias_method :write, :[]=
        
        def delete(key)
          key = [key].flatten.collect{|k| k.to_s}
          @mutex.synchronize {
            sub_cache = @cache
            key[0..-2].each do |subkey|
              sub_cache = (sub_cache[subkey] ||= {})
            end
            sub_cache.delete(key[-1])
          }
        end
        alias_method :remove, :delete
        
        def delete_if(&block)
          @hash.delete_if(&block)
        end
        
        def reap_old_caches
          @timestamps.each do |key,stamp|
            if stamp + @cache_ttl < Time.now
              delete(key)
            end  
          end
          GC.start
        end  
        
        def cache
          @cache
        end  
        
        def keys
          @cache.keys 
        end  
        
        def clear
          @cache = Hash.new
          @timestamps = Hash.new
          @mutex = Mutex.new          
        end
              
      end 
    end
  end   
end  