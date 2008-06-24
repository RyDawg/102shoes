module Merb
  
  module AuthenticationMixin
    require 'base64'
    
    def credentials
      if d = %w{REDIRECT_X_HTTP_AUTHORIZATION X_HTTP_AUTHORIZATION
             X-HTTP_AUTHORIZATION HTTP_AUTHORIZATION}.
             inject([]) { |d,h| request.env.has_key?(h) ? request.env[h].to_s.split : d }
        return Base64.decode64(d[1]).split(':')[0..1] if d[0] == 'Basic'
      end
    end
    
    def authenticated?
      username, password = *credentials
      username == Merb::Config[:basic_auth][:username] and password == Merb::Config[:basic_auth][:password]
    end
    
    def basic_authentication
      if !authenticated?
        throw :halt, :access_denied
      end
    end
      
    def access_denied
      set_status(401)
      headers['Content-type'] = 'text/plain'
      headers['Status'] = 'Unauthorized'
      headers['WWW-Authenticate'] = "Basic realm=\"#{Merb::Config[:basic_auth][:domain]}\""
      return 'Unauthorized'
    end  
      
  end
  
end