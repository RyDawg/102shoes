module Merb
  module Template
    autoload :Erubis,  'merb/template/erubis'
    autoload :Haml,  'merb/template/haml'    
    autoload :Markaby,  'merb/template/markaby'    
    autoload :XMLBuilder,  'merb/template/xml_builder'      
    
    EXTENSIONS = {} unless defined?(EXTENSIONS)
    
    # lookup the template_extensions for the extname of the filename
    # you pass. Answers with the engine that matches the extension
    def self.engine_for(file)
      engine_for_extension(File.extname(file)[1..-1])
    end
    
    def self.engine_for_extension(ext)
      const_get EXTENSIONS[ext]
    end
    
    def self.register_extensions(engine,extensions)
      raise ArgumentError unless engine.is_a?(Symbol) && extensions.is_a?(Array)
      extensions.each{ |ext| EXTENSIONS[ext] = engine }
    end
    
    # Register the default extensions.  They must be here
    # since the template engines will not be loaded until they
    # are directly referenced, or a file with their extension is found.
    # If these are declared inside the template engine then
    # they will never be found :(
    register_extensions( :Erubis, %w[erb])
    register_extensions( :Haml, %w[haml])
    register_extensions( :Markaby, %w[mab])
    register_extensions( :XMLBuilder, %w[builder])
    
  end
  
end
