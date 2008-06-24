module Merb
  module GlobalHelper;end
  
  module BootLoader
    class << self
      
      def initialize_merb
        require 'merb'
        @mtime = Time.now if Merb::Config[:reloader] == true
        # Register session types before merb_init.rb so that any additional
        # session stores will be added to the end of the list and become the
        # default.
        register_session_type('memory',
          Merb.framework_root / "merb" / "session" / "memory_session",
          "Using in-memory sessions; sessions will be lost whenever the server stops.")
        register_session_type('mem_cache',
          Merb.framework_root / "merb" / "session" / "mem_cache_session",
          "Using MemCache distributed memory sessions")
        register_session_type('cookie', # Last session type becomes the default
          Merb.framework_root / "merb" / "session" / "cookie_store",
          "Using 'share-nothing' cookie sessions (4kb limit per client)")
        require Merb.root / 'config/merb_init.rb'
        add_controller_mixins
      end
      
      def max_mtime( files = [] )
        files.map{ |file| File.mtime(file) rescue @mtime }.max
      end
      
      def register_session_type(name, file, description = nil)
        @registered_session_types ||= YAML::Omap.new
        @registered_session_types[name] = {
          :file => file,
          :description => (description || "Using #{name} sessions")
        }
      end
      
      def add_controller_mixins
        types = @registered_session_types
        Merb::Controller.class_eval do
          lib = File.join(Merb.framework_root, 'merb')
          session_store = Merb::Config[:session_store].to_s
          if ["", "false"].include?(session_store)
            puts "Not Using Sessions"
          elsif reg = types[session_store]
            if session_store == "cookie" 
              unless Merb::Config[:session_secret_key] && (Merb::Config[:session_secret_key].length >= 16)
                puts("You must specify a session_secret_key in your merb.yml, and it must be at least 16 characters\nbailing out...")
                exit! 
              end
              Merb::Controller.session_secret_key = Merb::Config[:session_secret_key]
            end
            require reg[:file]
            include ::Merb::SessionMixin
            puts reg[:description]
          else
            puts "Session store not found, '#{Merb::Config[:session_store]}'."
            puts "Defaulting to CookieStore Sessions"
            unless Merb::Config[:session_secret_key] && (Merb::Config[:session_secret_key].length >= 16)
              puts("You must specify a session_secret_key in your merb.yml, and it must be at least 16 characters\nbailing out...")
              exit! 
            end            
            Merb::Controller.session_secret_key = Merb::Config[:session_secret_key]
            require types['cookie'][:file]
            include ::Merb::SessionMixin
            puts "(plugin not installed?)"
          end
          
          if Merb::Config[:basic_auth]
            require lib + "/mixins/basic_authentication"
            include ::Merb::AuthenticationMixin
            puts "Basic Authentication mixed in"
          end
        end
      end
      
      def after_app_loads(&block)
        @after_app_blocks ||= []
        @after_app_blocks << block
      end
      
      def app_loaded?
        @app_loaded
      end
      
      def load_action_arguments(klasses = Merb::Controller._subclasses)
        begin
          klasses.each do |controller|
            controller = Object.full_const_get(controller)
            controller.action_argument_list = {}
            controller.callable_actions.each do |action, bool|
              controller.action_argument_list[action.to_sym] = ParseTreeArray.translate(controller, action).get_args
            end
          end
        rescue
          klasses.each { |controller| Object.full_const_get(controller).action_argument_list = {} }
        end if defined?(ParseTreeArray)
      end
      
      def template_paths(type = "*[a-zA-Z]")
        # This gets all templates set in the controllers template roots        
        template_paths = Merb::AbstractController._abstract_subclasses.map do |klass| 
          Object.full_const_get(klass)._template_root
        end.uniq.map do |path| 
          Dir["#{path}/**/#{type}"] 
        end
        
        # This gets the templates that might be created outside controllers
        # template roots.  eg app/views/shared/*
        template_paths << Dir["#{Merb.root}/app/views/**/*[a-zA-Z]"] if type == "*"
        
        template_paths.flatten.compact.uniq || []
      end
      
      def load_controller_template_path_cache
        Merb::AbstractController.reset_template_path_cache!
      
        template_paths.each do |template|
          Merb::AbstractController.add_path_to_template_cache(template)
        end
      end
      
      def load_inline_helpers
        partials = template_paths("_*.{erb,haml}")
        
        partials.each do |partial|
          case partial
          when /erb$/
            template = Erubis::Eruby.new(File.read(partial))
            template.def_method(Merb::GlobalHelper, partial.gsub(/[^\.a-zA-Z0-9]/, "__").gsub(/\./, "_"), partial)            
          when /haml$/
            if Object.const_defined?(:Haml) and Haml::Engine.instance_methods.include?('def_method')
              template = Haml::Engine.new(File.read(partial), :filename => partial)
              template.def_method(Merb::GlobalHelper, partial.gsub(/[^\.a-zA-Z0-9]/, "__").gsub(/\./, "_"))
            end
          end
        end
      end
      
      def load_application
    
        #Magic Class Loading => Not failing on missing parent due to alphabetical loading
        # Does a reverse alphaebetical search if classes failed in first pass
        # Will continue to reverse the list of failures until the size does change between
        # two passes

        orphaned_paths = []
        $LOAD_PATH.unshift( File.join(Merb.root,'/app/models') )
        $LOAD_PATH.unshift( File.join(Merb.root,'/app/controllers') )
        $LOAD_PATH.unshift( File.join(Merb.root , '/lib') )
        Merb.load_paths.each do |glob|
          Dir[Merb.root + glob].each do |m| 
            begin
              require m 
            rescue NameError
              orphaned_paths.unshift(m)
            end
          end
        end
        
        load_classes_with_requirements(orphaned_paths)
        
        load_action_arguments
        load_controller_template_path_cache
        load_inline_helpers
        @app_loaded = true
        load_libraries
        (@after_app_blocks || []).each { |b| b.call }
      end
      
      
      def load_classes_with_requirements(orphaned_paths)
        
        #Make the list unique
        orphaned_paths.uniq!
        
        while orphaned_paths.size > 0
          #Take the size for comparison later
          size_at_start = orphaned_paths.size

          fail_list = [] #List of failures
          
          # Try to load each path again, this time the order is reversed
          (orphaned_paths).each do |m|
            # Remove the path from the list
            orphaned_paths.delete(m)
            begin
              require m
            rescue NameError
              # Add it back on if it failed to load due to NameError
              fail_list.push(m)
            end
          end

          orphaned_paths.concat(fail_list)

          # Stop processing if everything loaded (size == 0) or if the size didn't change 
          # (ie something couldn't be loaded)
          break if(orphaned_paths.size == size_at_start || orphaned_paths.size == 0)
        end
        
        return orphaned_paths
      end
      
      
      def load_libraries
        # Load the Sass plugin of /public/stylesheets/sass exists
        begin
          require "sass/plugin" if File.directory?(Merb.root / "public" / "stylesheets" / "sass")  
        rescue LoadError
        end
        # If you don't use the JSON gem, disable auto-parsing of json params too
        if Merb::Config[:disable_json_gem]
          Merb::Request::parse_json_params = false
        else
          begin
            require 'json/ext'
          rescue LoadError
            require 'json/pure'
          end
        end
      end
      
      def remove_constant(const)
        parts = const.to_s.split("::")
        base = parts.size == 1 ? Object : Object.full_const_get(parts[0..-2].join("::"))
        object = parts[-1].intern
        Merb.logger.info("Removing constant #{object} from #{base}")
        base.send(:remove_const, object) if object
        Merb::Controller._subclasses.delete(const)
      end
      
      def reload
        return if !Merb::Config[:reloader]
        
        # First we collect all files in the project (this will also grab newly added files)
        project_files = Merb.load_paths.map { |path| Dir[Merb.root + path] }.flatten.uniq
        partials = template_paths("_*.*").map { |path| Dir[path] }.flatten.uniq
        project_mtime = max_mtime(project_files + partials) # Latest changed time of all project files
      
        return if @mtime.nil? || @mtime >= project_mtime   # Only continue if a file has changed
      
        project_files.each do |file|
          if File.mtime(file) >= @mtime
            # If the file has changed or been added since the last project reload time
            # remove any cannonical constants, based on what type of project file it is
            # and then reload the file
            begin
              constant = case file
                when %r[/app/(models|controllers|parts|mailers)/(.+)\.rb$]
                  $2.to_const_string
                when %r[/app/(helpers)/(.+)\.rb$]
                  "Merb::" + $2.to_const_string
                end
                remove_constant(constant)
            rescue NameError => e
              Merb.logger.warn "Couldn't remove constant #{constant}"
            end
            
            begin
              Merb.logger.info("Reloading file #{file}")
              old_subclasses = Merb::Controller._subclasses.dup
              load(file)
              loaded_classes = Merb::Controller._subclasses - old_subclasses
              load_action_arguments(loaded_classes)
            rescue Exception => e
              puts "Error reloading file #{file}: #{e}"
              Merb.logger.warn "  Error: #{e}"
            end
            
            # constant = file =~ /\/(controllers|models|mailers|helpers|parts)\/(.*).rb/ ? $2.to_const_string : nil
            # remove_constant($2.to_const_string, ($1 == "helpers") ? Merb : nil)
            # load file and puts "loaded file: #{file}"
          end
        end        
      
        # Rebuild the glob cache and erubis inline helpers
        load_controller_template_path_cache
        load_inline_helpers
      
        @mtime = project_mtime # As the last action, update the current @mtime
      end
    
    end # class << self
  end # BootLoader
end # Merb      
