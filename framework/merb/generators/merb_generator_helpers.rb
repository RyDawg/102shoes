# Provides some basic generator support that is generally required in various 
# Generators

module Merb
  module GeneratorHelpers
    
    class ModelGeneratorBase < RubiGen::Base

      default_options :author => nil
      attr_reader :name, :model_attributes
      attr_accessor :model_template_name, :model_test_generator_name, :migration_generator_name
      
      def initialize(runtime_args, runtime_options = {})
        super
        usage if args.empty?
        @class_name = args.shift.snake_case.to_const_string
        extract_options
      end

      def manifest
        unless @class_name
          puts banner
          exit 1
        end
        record do |m|

          # ensure there are no other definitions of this model already defined.
          m.class_collisions(@class_name)
          # Ensure appropriate folder(s) exists
          m.directory 'app/models'
          # 
          model_filename = @class_name.snake_case
          spec_filename = @class_name.snake_case.pluralize
          table_name = spec_filename


          # Create stubs
          m.template  model_template_name, 
                      "app/models/#{model_filename}.rb", 
                      :assigns => {  :class_name => @class_name, 
                                     :table_attributes => model_attributes}

          # Check to see if a scope has been set for which test framework to use.
          # If we try to run the dependency without an :rspec or :test_unit scope an
          # error will be raised.
          scopes = RubiGen::Base.sources.select{ |s| s.is_a?( RubiGen::PathFilteredSource )}.first.filters
          if scopes.include?(:rspec) || scopes.include?(:test_unit)
            unless options[:skip_testing] 
              m.dependency model_test_generator_name, [@class_name]
            end
          else
            puts "\nSelect a scope for :rspec or :test_unit in script/generate if you want to generate test stubs\n\n"
          end

          unless options[:skip_migration]
            m.dependency migration_generator_name,["add_model_#{spec_filename}"], :table_name => table_name, :table_attributes => model_attributes
          end

        end    
      end

      protected
        def banner
            <<-EOS
Creates a new model for merb

USAGE: #{$0} #{spec.name} NameOfModel [field:type field:type]

Example:
  #{$0} #{spec.name} person

  If you already have 3 migrations, this will create the AddModelPeople migration in
  schema/migration/004_add_model_people.rb

Options: 
  --skip-migration will not create a migration file

EOS
          end

        def add_options!(opts)
          opts.separator ''
          opts.separator 'Options:'
          # For each option below, place the default
          # at the top of the file next to "default_options"
          # opts.on("-a", "--author=\"Your Name\"", String,
          #         "Some comment about this option",
          #         "Default: none") { |options[:author]| }
          # opts.on("-v", "--version", "Show the #{File.basename($0)} version number and quit.")
          opts.on( "--skip-migration", "Don't generate a migration for this model") { |options[:skip_migration]| }
          opts.on( "--skip-testing", "Don't generate a test or spec file for this model") { |options[:skip_testing]| }
        end

        def extract_options
          # for each option, extract it into a local variable (and create an "attr_reader :author" at the top)
          # Templates can access these value via the attr_reader-generated methods, but not the
          # raw instance variable value.
          # @author = options[:author]
          # get the attributes into a format that can be used.
          attribute = Struct.new(:name, :type)
          @model_attributes = args.map{ |b| b.split(":").size > 1 ? attribute.new(*b.split(":")) : nil }.compact
        end
    end
    
    class MigrationGeneratorBase < RubiGen::Base

      default_options :author => nil

      attr_reader :name
      attr_accessor :migration_template_name
      
      def initialize(runtime_args, runtime_options = {})
        super
        usage if args.empty?
        @class_name = args.shift
        options[:table_name] ||= runtime_options[:table_name]
        extract_options
      end

      def manifest
        unless @class_name
          puts banner
          exit 1
        end
        record do |m|
          # Ensure appropriate folder(s) exists
          m.directory 'schema/migrations'

          # Create stubs
          highest_migration = Dir[Dir.pwd+'/schema/migrations/*'].map{|f| File.basename(f) =~ /^(\d+)/; $1}.max
          filename = format("%03d_%s", (highest_migration.to_i+1), @class_name.snake_case)
          m.template "new_migration.erb", "schema/migrations/#{filename}.rb", 
            :assigns => { :class_name => @class_name, 
                          :table_name => options[:table_name],
                          :table_attributes => options[:table_attributes] }

        end
      end

      protected
        def banner
          <<-EOS
Creates a new migration for merb

USAGE: #{$0} #{spec.name} NameOfMigration [field:type field:type]

Example:
  #{$0} #{spec.name} AddPeople

  If you already have 3 migrations, this will create the AddPeople migration in
  schema/migration/004_add_people.rb

  #{$0} #{spec.name} project --table-name projects_table name:string created_at:timestamp

  This will create a migration that creates a table call projects_table with these attributes:
    string :name
    timestamp :created_at

EOS
        end

        def add_options!(opts)
          opts.separator ''
          opts.separator 'Options:'
          # For each option below, place the default
          # at the top of the file next to "default_options"
          # opts.on("-a", "--author=\"Your Name\"", String,
          #         "Some comment about this option",
          #         "Default: none") { |options[:author]| }
          # opts.on("-v", "--version", "Show the #{File.basename($0)} version number and quit.")
          opts.on( "--table-name=\"table_name_for_migration\"", 
                    String,
                    "Include a create table with the given table name"){ |options[:table_name]| }
        end

        def extract_options
          # for each option, extract it into a local variable (and create an "attr_reader :author" at the top)
          # Templates can access these value via the attr_reader-generated methods, but not the
          # raw instance variable value.
          # @author = options[:author]
          if !options[:table_attributes]
            attribute = Struct.new(:name, :type)
            options[:table_attributes] = args.map{ |b| b.split(":").size == 2 ? attribute.new(*b.split(":")) : nil }.compact
          end
        end
    end
    
    class MerbModelTestGenerator < RubiGen::Base

      default_options :author => nil

      attr_reader :name, :model_test_template_name, :model_test_path_name, :model_test_file_suffix

      def initialize(runtime_args, runtime_options = {})
        super
        usage if args.empty?
        @class_name = args.shift.snake_case.to_const_string
        extract_options
      end

      def manifest
        unless @class_name
          puts banner
          exit 1
        end
        record do |m|
          # ensure there are no other definitions of this model already defined.
          # Ensure appropriate folder(s) exists
          m.directory model_test_path_name
          # 
          model_filename = @class_name.snake_case

          # Create stubs
          m.template model_test_template_name, 
            "#{model_test_path_name}/#{model_filename}_#{model_test_file_suffix}.rb", 
            :assigns => {:class_name => @class_name}
        end
      end

      protected


        def add_options!(opts)
          # opts.separator ''
          # opts.separator 'Options:'
          # For each option below, place the default
          # at the top of the file next to "default_options"
          # opts.on("-a", "--author=\"Your Name\"", String,
          #         "Some comment about this option",
          #         "Default: none") { |options[:author]| }
          # opts.on("-v", "--version", "Show the #{File.basename($0)} version number and quit.")
        end

        def extract_options
          # for each option, extract it into a local variable (and create an "attr_reader :author" at the top)
          # Templates can access these value via the attr_reader-generated methods, but not the
          # raw instance variable value.
          # @author = options[:author]
        end
    end
    
    # Pass the following options are available to this generatrs
    class ControllerGeneratorBase < RubiGen::Base

      default_options :author => nil

      attr_reader :name, :class_name, :file_name

      def initialize(runtime_args, runtime_options = {})
        super
        usage if args.empty?
        @name             = args.shift
        @class_name       = @name.camel_case #.pluralize
        @file_name        = @name.snake_case #.pluralize
        @engine           = runtime_options[:engine] || "erb" # set by subclasses only
        @template_actions = runtime_options[:actions] || %w[index] # Used by subclasses only
        @test_generator   = runtime_options[:test_stub_generator] || "merb_controller_test"
        @base_dest_folder = runtime_options[:base_dest_folder] || "app"
        extract_options
      end

      def manifest
        record do |m|
          
          # ensure there are no other definitions of this model already defined.
          m.class_collisions(@class_name)
          
          m.directory "#{@base_dest_folder}/controllers"
          m.template "controller.rb", "#{@base_dest_folder}/controllers/#{file_name}.rb", :assigns => {:actions => @template_actions}
          
          m.directory "#{@base_dest_folder}/views/#{file_name}"
          
          # Include templates if they exist
          @template_actions.each do |the_action|  
            template_name = "#{the_action}.html.#{@engine}"
            template_path = "/" + source_path(spec.name).split("/")[0..-2].join("/")

            if File.exists?(File.join(template_path,template_name))
              m.template template_name, "#{@base_dest_folder}/views/#{file_name}/#{template_name}"
            end
          end

          m.directory "#{@base_dest_folder}/helpers/"
          m.template "helper.rb", "#{@base_dest_folder}/helpers/#{file_name}_helper.rb"
          m.dependency @test_generator, [name], :destination => destination_root, :template_actions => @template_actions
        end
      end

      protected
        def banner
          <<-EOS
    Creates a Merb controller

    USAGE: #{$0} #{spec.name} name"
    EOS
        end

        def add_options!(opts)
          # opts.separator ''
          # opts.separator 'Options:'
          # For each option below, place the default
          # at the top of the file next to "default_options"
          # opts.on("-a", "--author=\"Your Name\"", String,
          #         "Some comment about this option",
          #         "Default: none") { |options[:author]| }
          # opts.on("-v", "--version", "Show the #{File.basename($0)} version number and quit.")
        end

        def extract_options
          # for each option, extract it into a local variable (and create an "attr_reader :author" at the top)
          # Templates can access these value via the attr_reader-generated methods, but not the
          # raw instance variable value.
          # @author = options[:author]
        end
    end
    
  end
end