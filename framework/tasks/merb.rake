def install_merb_script
  script_filepath = Merb.root / 'script/merb'
  FileUtils.rm script_filepath if File.exist? script_filepath
  tmpl = "#!/usr/bin/env ruby\nrequire File.expand_path(File.dirname(__FILE__)+'/../config/boot')\nrequire File.expand_path(File.dirname(__FILE__)+'/../framework/merb/server')\nMerb::Server.run\n"
  File.open(script_filepath, 'wb') {|f|
    f.write tmpl 
    f.chmod(0744)
  }
end

namespace :merb do
  desc "freeze the merb framework into merb for portability"
  task :freeze do
    FileUtils.rm_rf Merb.root / 'framework'
    FileUtils.cp_r Merb::framework_root, (Merb.root / 'framework')
    install_merb_script
    
    puts "  Freezing Merb Framework into framework"
    puts "  Use script/merb to start instead of plain merb"
  end
  desc "unfreeze this app from the framework and use system gem."
  task :unfreeze do
    FileUtils.rm_rf Merb.root / 'framework'
    FileUtils.rm Merb.root / 'script/merb'
    
    puts "  Removed: "
    puts "   - #{Merb.root / 'framework'} (recursive) "
    puts "   - #{Merb.root / 'script/merb'}"
  end
  
  desc "freeze the merb framework from svn, use REVISION=# to freeze a specific revision"
  task :freeze_from_svn do
    install_path = Merb.root / 'framework'
    revision = ENV['REVISION'] || 'HEAD'
    puts "  Removing old framework" if File.exist? install_path
    FileUtils.rm_rf install_path

    puts "  Freezing Merb Framework from svn, revision #{revision}"
    system "svn export -r #{revision} http://svn.devjavu.com/merb/trunk/lib #{install_path}"
    install_merb_script
    
    puts "  Use script/merb to start instead of plain merb"
  end
  
end

desc "Setup the Merb Environment by requiring merb and loading your merb_init.rb" 
task :merb_env do 
  require 'rubygems' 
  require 'merb' 
  Merb::Config[:environment] = ENV['MERB_ENV'] if ENV['MERB_ENV'] 
  Merb.environment = Merb::Config[:environment].nil? ? 'development' : Merb::Config[:environment] 
  load Merb.root+'/config/merb_init.rb' 
end