require 'uri'
require 'fileutils'
require 'tmpdir'

module Merb
  module Caching
    module Store
 
      class FileCache
            
        def initialize(name = "cache", keepalive = nil)
          @path = File.join(Merb.root, name)
          @keepalive = keepalive  
        end
      
        def []=(key,val)
          key = escape_filenames([key].flatten)
          FileUtils.mkdir_p(File.join(@path, *key[0..-2]), :mode => 0700)
          fn = File.join(@path, *key )
          encode_file(fn, val)
        end
        alias :put :[]=
        alias :write :[]=
        
        def [](key)          
          key = escape_filenames([key].flatten)          
          fn = File.join(@path, *key )
          return nil unless File.exists?(fn)
          decode_file(fn)
        end
        alias :get :[]
        alias_method :read, :[]
      
        def delete(key)          
          key = escape_filenames([key].flatten)
          f = File.join(@path, *key)
          FileUtils.rm_rf(f) 
        end
        
        def gc!
          return unless @keepalive
      
          now = Time.now
          all.each do |fn|
            expire_time = File.stat(fn).atime + @keepalive 
            File.delete(fn) if now > expire_time
          end
        end
        
        def clear
          all.each{|file| delete(File.basename(file)) }
        end

        private
      
        def decode_file(fn)
          val = nil
          File.open(fn,"r+b") do |f|
            f.flock(File::LOCK_EX)
            val = Marshal.load( f.read )
            f.flock(File::LOCK_UN)
          end
          return val
        end
      
        def encode_file(fn, value)
          File.open(fn, "wb") do |f| 
            f.flock(File::LOCK_EX)
            f.chmod(0600)
            f.write(Marshal.dump(value))
            f.flock(File::LOCK_UN)
          end
        end
        
        def all
          Dir.glob( File.join(@path, '*' ) )
        end
        # need this for fat filesystems
        def escape_filenames(fns)
          fns.collect do |fn|
            URI.escape(fn.to_s, /["\/:;|=,\[\]]/)            
          end
        end
      
      end
      
    end
  end
end

