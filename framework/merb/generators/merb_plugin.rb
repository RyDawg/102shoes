require 'fileutils'
require 'find'

module Merb
  
  class PluginGenerator    
    def self.run(path)
      require 'rubygems'
      require 'rubigen'

      require 'rubigen/scripts/generate'
      source = RubiGen::PathSource.new(:application, 
        File.join(File.dirname(__FILE__), "../../../app_generators"))
      RubiGen::Base.reset_sources
      RubiGen::Base.append_sources source
      RubiGen::Scripts::Generate.new.run([path], :generator => 'merb_plugin', :backtrace => true)
    end  

  end
        
end  

