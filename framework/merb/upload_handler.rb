module Mongrel
  module Const
    POST         = 'POST'.freeze         unless const_defined?(:POST)
    PUT          = 'PUT'.freeze          unless const_defined?(:PUT)
    QUERY_STRING = 'QUERY_STRING'.freeze unless const_defined?(:QUERY_STRING)
    UPLOAD_ID    = 'upload_id'.freeze
  end
  
  unless ENV['EVENT'] || ENV['SWIFT']
    HttpHandler.class_eval do
      def request_aborted(params)
      end
    end
    
    HttpRequest.class_eval do
      def initialize_with_abort(params, socket, dispatchers)
        initialize_without_abort(params, socket, dispatchers)
        dispatchers.each {|d| d.request_aborted(params) if @body.nil? && d }
      end
      
      alias_method :initialize_without_abort, :initialize
      alias_method :initialize, :initialize_with_abort
    end
  end
end


class MerbUploadHandler < Mongrel::HttpHandler

  def initialize(options = {})
    @path_match     = Regexp.new(options[:upload_path_match])
    @frequency      = options[:upload_frequency] || 3
    @request_notify = true
    if options[:start_drb]
      require 'drb'
      DRb.start_service
      Mongrel.const_set :Uploads, DRbObject.new(nil, "druby://#{options[:host]}:#{options[:drb_server_port]}").upload_progress
    else
      Mongrel.const_set :Uploads, Merb::UploadProgress.new
    end
    Mongrel::Uploads.debug = true if options[:debug]
  end

  def request_begins(params)
    upload_notify(:add, params, params[Mongrel::Const::CONTENT_LENGTH].to_i)
  end

  def request_progress(params, clen, total)
    upload_notify(:mark, params, clen)
  end

  def process(request, response)
    upload_notify(:finish, request.params)
  end
  
  def request_aborted(params)
    return unless upload_id = valid_upload?(params)
    Mongrel::Uploads.finish(upload_id)
    Merb.logger.info "#{self.class.name} - request aborted for " <<
      "id: #{upload_id.inspect}, params: #{params.inspect}"
  end

  private
    def upload_notify(action, params, *args)
      return unless upload_id = valid_upload?(params)
      if action == :mark
        last_checked_time = Mongrel::Uploads.last_checked(upload_id)
        return unless last_checked_time && Time.now - last_checked_time > @frequency
      end
      Mongrel::Uploads.send(action, upload_id, *args) 
      Mongrel::Uploads.update_checked_time(upload_id) unless action == :finish
    end
    
    def valid_upload?(params)
      params[Mongrel::Const::PATH_INFO].match(@path_match) &&
        [Mongrel::Const::POST, Mongrel::Const::PUT].include?(params[Mongrel::Const::REQUEST_METHOD]) &&
        Mongrel::HttpRequest.query_parse(params[Mongrel::Const::QUERY_STRING])[Mongrel::Const::UPLOAD_ID]
    end
end

