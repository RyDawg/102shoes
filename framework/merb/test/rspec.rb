require 'hpricot'
require 'spec'

# Get all the rspec matchers for merb and include them
Dir[(File.dirname(__FILE__) + "/rspec_matchers/**/*.rb")].each do |file|
  require "#{file[0...-3]}"
end

module Merb
  module Test
    module RspecMatchers
      
      include ControllerMatchers
      include MarkupMatchers

    end
  end
end