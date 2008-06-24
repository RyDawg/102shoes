class Mongrel::HttpResponse
  NO_CLOSE_STATUS_FORMAT = "HTTP/1.1 %d %s\r\n".freeze
  def send_status_no_connection_close(content_length=@body.length)
    unless @status_sent
      @header['Content-Length'] = content_length unless @status == 304
      write(NO_CLOSE_STATUS_FORMAT % [@status, Mongrel::HTTP_STATUS_CODES[@status]])
      @status_sent = true
    end
  end
end  

class MerbHandler < Mongrel::HttpHandler
  @@file_only_methods    = ["GET","HEAD"]
  @@path_prefix          = nil
  @@path_prefix_original = nil
  
  class << self
    # Use :path_prefix in merb.yml to set this
    def path_prefix() @@path_prefix_original end
    def path_prefix=(prefix)
      @@path_prefix_original = prefix
      @@path_prefix          = (prefix.is_a?(String) ? /^#{prefix.escape_regexp}/ : prefix)
    end
  end
  
  # Take the name of a directory and use that as the doc root or public
  # directory of your site. This is set to the root of your merb app + '/public'
  # by default.
  def initialize(dir, mongrel_x_sendfile=true, opts = {})
    @files = Mongrel::DirHandler.new(dir,false)
    @mongrel_x_sendfile = mongrel_x_sendfile
  end
  
  # process incoming http requests and do a number of things
  # 1. Check for rails style cached pages. add .html to the url and see if
  # there is a static file in public that matches. serve that file directly
  # without invoking Merb and be done with it.
  # 2. Serve static asset and html files directly from public/ if they exist.
  # 3. If none of the above apply, we take apart the request url and feed it
  # into Merb::RouteMatcher to let it decide which controller and method will
  # serve the request.
  # 4. After the controller has done its thing, we check for the X-SENDFILE
  # header. if you set this header to the path of a file in your controller
  # then mongrel will serve the file directly and your controller can go on
  # processing other requests.
  def process(request, response) 
    return if response.socket.closed?
       
    start      = Time.now
    benchmarks = {}
    
    Merb.logger.info("\nRequest: REQUEST_URI: #{
      request.params[Mongrel::Const::REQUEST_URI]}  (#{Time.now.strftime("%Y-%m-%d %H:%M:%S")})")
    
    # Truncate the request URI if there's a path prefix so that an app can be
    # hosted inside a subdirectory, for example.
    if @@path_prefix
      if request.params[Mongrel::Const::PATH_INFO] =~ @@path_prefix
        Merb.logger.info("Path prefix #{@@path_prefix.inspect} removed from PATH_INFO and REQUEST_URI.")
        request.params[Mongrel::Const::PATH_INFO].sub!(@@path_prefix, '')
        request.params[Mongrel::Const::REQUEST_URI].sub!(@@path_prefix, '')
        path_info = request.params[Mongrel::Const::PATH_INFO]
      else
        raise "Path prefix is set to '#{@@path_prefix.inspect}', but is not in the REQUEST_URI. "
      end
    else
      path_info = request.params[Mongrel::Const::PATH_INFO]
    end
    
    # Rails style page caching. Check the public dir first for .html pages and
    # serve directly. Otherwise fall back to Merb routing and request
    # dispatching.
    page_cached = path_info + ".html"
    get_or_head = @@file_only_methods.include? request.params[Mongrel::Const::REQUEST_METHOD]

    if get_or_head && @files.can_serve(path_info)
      # File exists as-is so serve it up
      Merb.logger.info("Serving static file: #{path_info}")
      @files.process(request,response)
    elsif get_or_head && @files.can_serve(page_cached)
      # Possible cached page, serve it up
      Merb.logger.info("Serving static file: #{page_cached}")
      request.params[Mongrel::Const::PATH_INFO] = page_cached
      @files.process(request,response)
    else
      # Let Merb:Dispatcher find the route and call the filter chain and action
      controller, action      = Merb::Dispatcher.handle(request, response)  
      benchmarks.merge!(controller._benchmarks)
      benchmarks[:controller] = controller.class.to_s
      benchmarks[:action]     = action

      Merb.logger.info("Routing to controller: #{controller.class} action: #{action}\nRoute Recognition & Parsing HTTP Input took: #{benchmarks[:setup_time]} seconds")
      
      sendfile, clength = nil
      response.status   = controller.status
      # Check for the X-SENDFILE header from your Merb::Controller and serve
      # the file directly instead of buffering.
      controller.headers.each do |k, v|
        if k =~ /^X-SENDFILE$/i
          sendfile = v
        elsif k =~ /^CONTENT-LENGTH$/i
          clength = v.to_i
        else
          [*v].each do |vi|
            response.header[k] = vi
          end
        end
      end
      
      if sendfile
        if @mongrel_x_sendfile
          # we want to emulate X-Sendfile header internally in mongrel
          benchmarks[:sendfile_time] = Time.now - start        
          Merb.logger.info("X-SENDFILE: #{sendfile}\nComplete Request took: #{
            benchmarks[:sendfile_time]} seconds")
          file_status     = File.stat(sendfile)
          response.status = 200
          # Set the last modified times as well and etag for all files
          response.header[Mongrel::Const::LAST_MODIFIED] = file_status.mtime.httpdate
          # Calculated the same as apache, not sure how well the works on win32
          response.header[Mongrel::Const::ETAG] = Mongrel::Const::ETAG_FORMAT % [file_status.mtime.to_i, file_status.size, file_status.ino]
          # Send a status with out content length
          response.send_status(file_status.size)
          response.send_header
          response.send_file(sendfile)  
        else
          # we want to pass thru the X-Sendfile header so apache or whatever 
          # front server can handle it
          response.header['X-Sendfile'] = sendfile
          response.header['Content-length'] = clength || File.size(sendfile)
          response.finished
        end    
      elsif controller.body.respond_to? :read
        response.send_status(clength)
        response.send_header
        while chunk = controller.body.read(16384)
          response.write(chunk)
        end
        if controller.body.respond_to? :close
          controller.body.close
        end
      elsif Proc === controller.body
        controller.body.call
      else
        # Render response from successful controller
        body = (controller.body.to_s rescue '') 
        response.send_status(body.length)
        response.send_header
        response.write(body)
      end

      total_request_time = Time.now - start
      benchmarks[:total_request_time] = total_request_time
        
      Merb.logger.info("Request Times: #{benchmarks.inspect}\nResponse status: #{response.status}\nComplete Request took: #{total_request_time} seconds, #{1.0/total_request_time} Requests/Second\n\n")
    end
  rescue Object => e
    # if an exception is raised here then something is 
    # wrong with the dispatcher code so we shouldn't pass the
    # exception back in or we might end up in a loop
    response.send_status(500)
    response.send_header
    response.write("500 Internal Server Error")
    Merb.logger.error(Merb.exception(e))
  ensure
    Merb.logger.flush
  end
end
