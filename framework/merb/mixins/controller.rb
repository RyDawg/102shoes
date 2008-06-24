module Merb
  # Module that is mixed in to all implemented controllers.
  module ControllerMixin
    
    # Renders the block given as a parameter using chunked
    # encoding.
    #
    # ==== Examples
    #
    #   def stream
    #     prefix = '<p>'
    #     suffix = "</p>\r\n"
    #     render_chunked do
    #       IO.popen("cat /tmp/test.log") do |io|
    #         done = false
    #         until done
    #           sleep 0.3
    #           line = io.gets.chomp
    #           
    #           if line == 'EOF'
    #             done = true
    #           else
    #             send_chunk(prefix + line + suffix)
    #           end
    #         end
    #       end
    #     end
    #   end
    #
    def render_chunked(&blk)
      headers['Transfer-Encoding'] = 'chunked'
      Proc.new {
        response.send_status_no_connection_close(0)
        response.send_header
        blk.call
        response.write("0\r\n\r\n")
      }
    end
    
    # Returns a +Proc+ that Mongrel can call later, allowing
    # Merb to release the thread lock and render another request.
    #
    def render_deferred(&blk)
      Proc.new {
        result = blk.call
        response.send_status(result.length)
        response.send_header
        response.write(result)
      }
    end
    
    # Writes a chunk from render_chunked to the response that
    # is sent back to the client.
    def send_chunk(data)
      response.write('%x' % data.size + "\r\n")
      response.write(data + "\r\n")
    end
    
    # Redirects to a URL.  The +url+ parameter can be either 
    # a relative URL (e.g., +/posts/34+) or a fully-qualified URL
    # (e.g., +http://www.merbivore.com/+).
    #
    # ==== Parameters
    #
    # +url+ - URL to redirect to; it can be either a relative or 
    # fully-qualified URL.
    # +permanent+ - Whether to use permanent redirection.
    #
    def redirect(url, permanent = false)
      status = permanent ? 301 : 302
      Merb.logger.info("Redirecting to: #{url} status: #{status}")
      set_status(status)
      headers['Location'] = url
      "<html><body>You are being <a href=\"#{url}\">redirected</a>.</body></html>"
    end
    
    # Sends a file over HTTP.  When given a path to a file, it will set the
    # right headers so that the static file is served directly.
    #
    # ==== Parameters
    # 
    # +file+ - Path to file to send to the client.
    #
    def send_file(file, opts={})
      opts.update(Merb::Const::DEFAULT_SEND_FILE_OPTIONS.merge(opts))
      disposition = opts[:disposition].dup || 'attachment'
      disposition << %(; filename="#{opts[:filename] ? opts[:filename] : File.basename(file)}")
      headers.update(
        'Content-Type'              => opts[:type].strip,  # fixes a problem with extra '\r' with some browsers
        'Content-Disposition'       => disposition,
        'Content-Transfer-Encoding' => 'binary',
        'X-SENDFILE'                => file
      )
      return
    end
    
    # Streams a file over HTTP.
    #
    # ==== Example
    #
    # stream_file( { :filename => file_name, 
    #                :type => content_type,
    #                :content_length => content_length }) do
    #   AWS::S3::S3Object.stream(user.folder_name + "-" + user_file.unique_id, bucket_name) do |chunk|
    #       response.write chunk
    #   end
    # end
    def stream_file(opts={}, &stream)
      opts.update(Merb::Const::DEFAULT_SEND_FILE_OPTIONS.merge(opts))
      disposition = opts[:disposition].dup || 'attachment'
      disposition << %(; filename="#{opts[:filename]}")
      response.headers.update(
        'Content-Type'              => opts[:type].strip,  # fixes a problem with extra '\r' with some browsers
        'Content-Disposition'       => disposition,
        'Content-Transfer-Encoding' => 'binary',
        'CONTENT-LENGTH'            => opts[:content_length]
      )
      response.send_status(opts[:content_length])
      response.send_header
      stream
    end
    

    # Uses the nginx specific +X-Accel-Redirect+ header to send
    # a file directly from nginx. For more information, see the nginx wiki:
    # http://wiki.codemongers.com/NginxXSendfile
    #
    # ==== Parameters
    # 
    # +file+ - Path to file to send to the client.
    #
    def nginx_send_file(file)
      headers['X-Accel-Redirect'] = File.expand_path(file)
      return
    end  
  
    # Sets a cookie to be included in the response.  This method is used
    # primarily internally in Merb.
    #
    # If you need to set a cookie, then use the +cookies+ hash.
    #
    def set_cookie(name, value, expires)
      (headers['Set-Cookie'] ||=[]) << (Merb::Const::SET_COOKIE % [
        name.to_s, 
        escape(value.to_s), 
        # Cookie expiration time must be GMT. See RFC 2109
        expires.gmtime.strftime(Merb::Const::COOKIE_EXPIRATION_FORMAT)
      ])
    end
    
    # Marks a cookie as deleted and gives it an expires stamp in 
    # the past.  This method is used primarily internally in Merb.
    #
    # Use the +cookies+ hash to manipulate cookies instead.
    #
    def delete_cookie(name)
      set_cookie(name, nil, Merb::Const::COOKIE_EXPIRED_TIME)
    end
  end
end
