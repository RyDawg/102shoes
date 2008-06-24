require 'rubygems'

# Make the app's "gems" directory a place where gems are loaded from
# This needs to go here for using in a shared envirionment where Erubis may not
# be available
if File.exists?(File.join(Dir.pwd,  "gems")) && File.directory?(File.join(Dir.pwd,"gems"))
  Gem.clear_paths
  Gem.path.unshift(File.join(Dir.pwd,"gems"))
end


require 'optparse'
require 'ostruct'
require 'fileutils'
require 'yaml'

# this is so we can test for HAML features for HAML partial inlining
unless Gem.cache.search("haml").empty?
  gem "haml"
  require "haml"
end

require File.join(File.dirname(__FILE__), 'config')

module Merb

  class Server
    
    class << self
      
      def run
        ::Merb::Config.parse_args
                
        if Merb::Config[:cluster]
          Merb::Config[:port].to_i.upto(Merb::Config[:port].to_i+Merb::Config[:cluster].to_i-1) do |port|
            unless alive?(port)
              delete_pidfiles(port)
              puts "Starting merb server on port: #{port}"
              start(port)
            else
              raise "Merb is already running on port: #{port}"
            end
          end   
        elsif Merb::Config[:daemonize]
          unless alive?(Merb::Config[:port])  
            delete_pidfiles(Merb::Config[:port])
            start(Merb::Config[:port])
          else
            raise "Merb is already running on port: #{port}"
          end
        else
          trap('TERM') { exit }
          mongrel_start(Merb::Config[:port])
        end     
        
      end
      
      def store_pid(pid,port)
        File.open("#{Merb::Config[:merb_root]}/log/merb.#{port}.pid", 'w'){|f| f.write("#{Process.pid}\n")}
      end
      
      def alive?(port)
        f = Merb::Config[:merb_root] + "/log/merb.#{port}.pid"
        pid = IO.read(f).chomp.to_i
        Process.kill(0, pid)
        true
      rescue
        false
      end
      
      def kill(ports, sig=9)
        begin
          Dir[Merb::Config[:merb_root] + "/log/merb.#{ports == 'all' ? '*' : ports }.pid"].each do |f|
            pid = IO.read(f).chomp.to_i
            Process.kill(sig, pid)
            FileUtils.rm f
            puts "killed PID #{pid} with signal #{sig}"
          end
        rescue
          puts "Failed to kill! #{k}"
        ensure  
          exit
        end
      end
      
      def start(port,what=:mongrel_start)
        fork do
          Process.setsid
          exit if fork
          File.umask 0000
          STDIN.reopen "/dev/null"
          STDOUT.reopen "/dev/null", "a"
          STDERR.reopen STDOUT
          trap("TERM") { exit }
          Dir.chdir Merb::Config[:merb_root]
          send(what, port)
        end
      end
      
      def webrick_start(port)
        Merb::BootLoader.initialize_merb
        store_pid(Process.pid, port)
        require 'rack'
        require 'merb/rack_adapter'
        ::Rack::Handler::WEBrick.run Merb::Rack::Adapter.new,
          :Port => port
      end

      def fastcgi_start
        Merb::BootLoader.initialize_merb
        require 'rack'
        require 'merb/rack_adapter'
        ::Rack::Handler::FastCGI.run Merb::Rack::Adapter.new
      end
      
      def delete_pidfiles(portor_star='*')
        Dir["#{Merb::Config[:merb_root]}/log/merb.#{portor_star}.pid"].each do |pid|
          FileUtils.rm(pid)  rescue nil
        end
      end  
      
      def drbserver_start(port)
        puts "Starting merb drb server on port: #{port}"
        require 'merb/drb_server'
        Merb::BootLoader.initialize_merb
        store_pid(Process.pid, "drb.#{port}")
        drb_init = File.join(Merb.root, "/config/drb_init")
        require drb_init if File.exist?(drb_init)
        DRb.start_service("druby://#{Merb::Config[:host]}:#{port}", Merb::DrbServiceProvider)
        DRb.thread.join
      end  
      
      def mongrel_start(port)
        store_pid(Process.pid, port)
        Merb::Config[:port] = port
        unless  Merb::Config[:generate] ||  Merb::Config[:console] ||  Merb::Config[:only_drb] ||  Merb::Config[:kill]
          puts %{Merb started with these options:}
          puts Merb::Config.to_yaml; puts
        end
        Merb::BootLoader.initialize_merb
      
        mconf_hash = {:host => (Merb::Config[:host]||"0.0.0.0"), :port => (port ||4000)}
        if Merb::Config[:user] and Merb::Config[:group]
          mconf_hash[:user]   = Merb::Config[:user]
          mconf_hash[:group]  = Merb::Config[:group]
        end
        mconfig = Mongrel::Configurator.new(mconf_hash) do
          listener do
            uri( "/", :handler => MerbUploadHandler.new(Merb::Config), :in_front => true) if Merb::Config[:upload_path_match]
            uri "/", :handler => MerbHandler.new(Merb.root+'/public', Merb::Config[:mongrel_x_sendfile])
            uri "/favicon.ico", :handler => Mongrel::Error404Handler.new("") 
          end
          MerbHandler.path_prefix = Merb::Config[:path_prefix]
      
          trap("INT") { stop }
          run
        end
        mconfig.join
      end
      
      def config
        Merb::Config
      end
      
    end # class << self
    
  end # Server

end # Merb
