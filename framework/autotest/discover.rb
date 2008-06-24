Autotest.add_discovery do
  "merb" if File.exist?('config/merb_init.rb')
end