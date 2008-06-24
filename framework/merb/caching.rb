corelib = Merb.framework_root + '/merb/caching'

%w[ action_cache
    fragment_cache
  ].each {|fn| require File.join(corelib, fn)}