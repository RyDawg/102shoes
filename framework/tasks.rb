$VERBOSE = nil

# Load Merb rakefile extensions
Dir["#{File.dirname(__FILE__)}/tasks/**/*.rake"].each { |ext| load ext }

# Load any custom rakefile extensions
Dir["./lib/tasks/**/*.rake"].sort.each { |ext| load ext }
