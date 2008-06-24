require 'rubygems'
if ENV['SWIFT']
  begin
    require 'swiftcore/swiftiplied_mongrel'
    puts "Using Swiftiplied Mongrel"
  rescue LoadError
    require 'mongrel'
	puts "SWIFT variable set but not installed - falling back to normal Mongrel"
  end
elsif ENV['EVENT']
  begin
    require 'swiftcore/evented_mongrel' 
    puts "Using Evented Mongrel"
  rescue LoadError
    require 'mongrel'
	puts "EVENT variable set but swiftiply not installed - falling back to normal Mongrel"
  end
elsif ENV['PACKET']
  begin
    require 'packet_mongrel' 
    puts "Using Packet Mongrel"
  rescue LoadError
    require 'mongrel'
	puts "PACKET variable set but packet not installed - falling back to normal Mongrel"
  end
else
 require 'mongrel'
end
require 'set'
require 'fileutils'
require 'merb/erubis_ext'
require 'merb/logger'
require 'merb/version'
require 'merb/config'

autoload :MerbUploadHandler, 'merb/upload_handler'
autoload :MerbHandler, 'merb/mongrel_handler'

module Merb
  autoload :AbstractController,     'merb/abstract_controller'
  autoload :Assets,                 'merb/assets'
  autoload :Authentication,         'merb/mixins/basic_authentication'
  autoload :Caching,                'merb/caching'
  autoload :Const,                  'merb/constants'
  autoload :Controller,             'merb/controller'
  autoload :ControllerExceptions,   'merb/exceptions'
  autoload :ControllerMixin,        'merb/mixins/controller'
  autoload :Cookies,                'merb/cookies'
  autoload :Dispatcher,             'merb/dispatcher'
  autoload :DrbServiceProvider,     'drb_server'
  autoload :ErubisCaptureMixin,     'merb/mixins/erubis_capture'
  autoload :GeneralControllerMixin, 'merb/mixins/general_controller'
  autoload :InlinePartialMixin,     'merb/mixins/inline_partial'
  autoload :MailController,         'merb/mail_controller'
  autoload :Mailer,                 'merb/mailer'
  autoload :PartController,         'merb/part_controller'
  autoload :Plugins,                'merb/plugins'
  autoload :Rack,                   'merb/rack_adapter'
  autoload :RenderMixin,            'merb/mixins/render'
  autoload :Request,                'merb/request'
  autoload :ResponderMixin,         'merb/mixins/responder'
  autoload :Router,                 'merb/router'
  autoload :Server,                 'merb/server'
  autoload :SessionMixin,           'merb/session'
  autoload :Template,               'merb/template'
  autoload :UploadProgress,         'merb/upload_progress'
  autoload :ViewContext,            'merb/view_context'
  autoload :ViewContextMixin,       'merb/mixins/view_context'
  autoload :WebControllerMixin,     'merb/mixins/web_controller'
  
  # This is where Merb-global variables are set and held
  class << self
    
		def environment
			@environment
		end
		
		def environment=(value)
			@environment = value
		end
		
		def load_paths
			@load_paths ||= [ "/app/models/**/*.rb",
				"/app/controllers/application.rb",
				"/app/controllers/**/*.rb",
				"/app/helpers/**/*.rb",
				"/app/mailers/**/*.rb",
				"/app/parts/**/*.rb",
				"/config/router.rb"
			]
		end
		
		# Application paths
		def root
		  @root || Merb::Config[:merb_root] || Dir.pwd
		end
		
		def root_path(*path)
			File.join(root, *path)
		end
		
		def view_path
			root_path 'app/views'
		end
		
		def model_path
			root_path 'app/models'
		end
		
		def application_controller_path
			root_path 'app/controllers/application.rb'
		end
		
		def controller_path
			root_path 'app/controllers'
		end
		
		def helper_path
			root_path 'app/helpers'
		end
		
		def mailer_path
			root_path 'app/mailers'
		end
		
		def part_path
		  root_path 'app/parts'
		end
		
		def router_path
			root_path '/config/router.rb'
		end
		
		def root=(value)
			@root ||= value
		end
		
		# Logger settings
		attr :logger, true
		
		def log_path
		  if $TESTING
        "#{Merb.root}/log/merb_test.log"
      elsif !(Merb::Config[:daemonize] || Merb::Config[:cluster] )
        STDOUT
      else
        "#{Merb.root}/log/merb.#{Merb::Config[:port]}.log"
		  end
		end
		
		# Framework paths
		
		def framework_root
			@framework_root ||= File.dirname(__FILE__)
		end
		
		def framework_path(path)
			File.join(framework_root, path)
		end
		
		def lib_path
			framework_path 'merb'
		end
		
		def skeleton_path
			framework_path '../app_generators/merb/templates'
		end
  end

  # Set up default generator scope
  GENERATOR_SCOPE = [:merb_default, :merb, :rspec]
end

# Load up the core extensions
require Merb.framework_path('merb/core_ext')
require Merb.framework_path('merb/version')

# Set the environment
Merb.environment =  Merb::Config[:environment] || ($TESTING ? 'test' : 'development')

# Create and setup the logger
Merb.logger = Merb::Logger.new(Merb.log_path)
Merb.logger.level = Merb::Logger.const_get(Merb::Config[:log_level].upcase) rescue Merb::Logger::INFO

if $TESTING
  test_files = File.join(Merb.lib_path, 'test', '*.rb')
  Dir[test_files].each { |file| require file }
end