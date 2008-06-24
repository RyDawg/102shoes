module Merb
  # Keeps track of the status of all currently processing uploads
  class UploadProgress
    include DRbUndumped if defined?(DRbUndumped)
    attr_accessor :debug
    def initialize
      @guard    = Mutex.new
      @counters = {}
    end
  
    def check(upid)
      @counters[upid].last rescue nil
    end
  
    def last_checked(upid)
      @counters[upid].first rescue nil
    end
  
    def update_checked_time(upid)
      @guard.synchronize { @counters[upid][0] = Time.now }
    end
  
    def add(upid, size)
      @guard.synchronize do
        @counters[upid] = [Time.now, {:size => size, :received => 0}]
        puts "#{upid}: Added" if @debug
      end
    end
  
    def mark(upid, len)
      return unless status = check(upid)
      puts "#{upid}: Marking" if @debug
      @guard.synchronize { status[:received] = status[:size] - len }
    end
  
    def finish(upid)
      @guard.synchronize do
        puts "#{upid}: Finished" if @debug
        @counters.delete(upid)
      end
    end
  
    def list
      @counters.keys.sort
    end
  end
  
end