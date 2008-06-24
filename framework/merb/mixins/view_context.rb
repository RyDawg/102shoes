module Merb
  # The ViewContextMixin module provides a number of helper methods to views for
  # linking to assets and other pages, dealing with JavaScript, and caching.
  module ViewContextMixin
    
    include Merb::Assets::AssetHelpers
    
    # :section: Accessing Assets
    # Merb provides views with convenience methods for links images and other assets.
    
    # Creates a link for the URL given in +url+ with the text in +name+; HTML options are given in the +opts+
    # hash.
    #
    # ==== Options
    # The +opts+ hash is used to set HTML attributes on the tag.
    #    
    # ==== Examples
    #   link_to("The Merb home page", "http://www.merbivore.com/")
    #   # => <a href="http://www.merbivore.com/">The Merb home page</a>
    #
    #   link_to("The Ruby home page", "http://www.ruby-lang.org", {'class' => 'special', 'target' => 'blank'})
    #   # => <a href="http://www.ruby-lang.org" class="special" target="blank">The Ruby home page</a>
    #
    #   link_to p.title, "/blog/show/#{p.id}"
    #   # => <a href="blog/show/13">The Entry Title</a>
    #
    def link_to(name, url='', opts={})
      opts[:href] ||= url
      %{<a #{ opts.to_xml_attributes }>#{name}</a>}
    end
  
    # Creates an image tag with the +src+ attribute set to the +img+ argument.  The path
    # prefix defaults to <tt>/images/</tt>.  The path prefix can be overriden by setting a +:path+
    # parameter in the +opts+ hash.  The rest of the +opts+ hash sets HTML attributes.
    #
    # ==== Options
    # path:: Sets the path prefix for the image (defaults to +/images/+)
    # 
    # All other options in +opts+ set HTML attributes on the tag.
    #
    # ==== Examples
    #   image_tag('foo.gif') 
    #   # => <img src='/images/foo.gif' />
    #   
    #   image_tag('foo.gif', :class => 'bar') 
    #   # => <img src='/images/foo.gif' class='bar' />
    #
    #   image_tag('foo.gif', :path => '/files/') 
    #   # => <img src='/files/foo.gif' />
    #
    #   image_tag('http://test.com/foo.gif')
    #   # => <img src="http://test.com/foo.gif">
    def image_tag(img, opts={})
      opts[:path] ||= 
        if img =~ %r{^https?://}
          ''
        else
          if Merb::Config[:path_prefix]
            Merb::Config[:path_prefix] + '/images/'
          else
            '/images/'
          end
        end
      opts[:src] ||= opts.delete(:path) + img
      %{<img #{ opts.to_xml_attributes } />}    
    end

    # :section: JavaScript related functions
    #
    
    # Escapes text for use in JavaScript, replacing unsafe strings with their
    # escaped equivalent.
    #
    # ==== Examples
    #   escape_js("'Lorem ipsum!' -- Some guy")
    #   # => "\\'Lorem ipsum!\\' -- Some guy"
    #
    #   escape_js("Please keep text\nlines as skinny\nas possible.")
    #   # => "Please keep text\\nlines as skinny\\nas possible."
    def escape_js(javascript)
      (javascript || '').gsub('\\','\0\0').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }
    end
    
    # Creates a link tag with the text in +name+ and the <tt>onClick</tt> handler set to a JavaScript 
    # string in +function+.
    #
    # ==== Examples
    #   link_to_function('Click me', "alert('hi!')")
    #   # => <a href="#" onclick="alert('hi!'); return false;">Click me</a>
    #
    #   link_to_function('Add to cart', "item_total += 1; alert('Item added!');")
    #   # => <a href="#" onclick="item_total += 1; alert('Item added!'); return false;">Add to cart</a>
    #   
    def link_to_function(name, function)
      %{<a href="#" onclick="#{function}; return false;">#{name}</a>}
    end
    
    # The js method simply calls +to_json+ on an object in +data+; if the object
    # does not implement a +to_json+ method, then it calls +to_json+ on 
    # +data.inspect+.
    #
    # ==== Examples
    #   js({'user' => 'Lewis', 'page' => 'home'})
    #   # => "{\"user\":\"Lewis\",\"page\":\"home\"}"
    #
    #   my_array = [1, 2, {"a"=>3.141}, false, true, nil, 4..10]
    #   js(my_array)
    #   # => "[1,2,{\"a\":3.141},false,true,null,\"4..10\"]"
    #
    def js(data)
      if data.respond_to? :to_json
        data.to_json
      else
        data.inspect.to_json
      end
    end
      
    # :section: External JavaScript and Stylesheets
    #
    # You can use require_js(:prototype) or require_css(:shinystyles)
    # from any view or layout, and the scripts will only be included once
    # in the head of the final page. To get this effect, the head of your layout you will
    # need to include a call to include_required_js and include_required_css.
    #
    # ==== Examples
    #   # File: app/views/layouts/application.html.erb
    #
    #   <html>
    #     <head>
    #       <%= include_required_js %>
    #       <%= include_required_css %>
    #     </head>
    #     <body>
    #       <%= catch_content :layout %>
    #     </body>
    #   </html>
    # 
    #   # File: app/views/whatever/_part1.herb
    #
    #   <% require_js  'this' -%>
    #   <% require_css 'that', 'another_one' -%>
    # 
    #   # File: app/views/whatever/_part2.herb
    #
    #   <% require_js 'this', 'something_else' -%>
    #   <% require_css 'that' -%>
    #
    #   # File: app/views/whatever/index.herb
    #
    #   <%= partial(:part1) %>
    #   <%= partial(:part2) %>
    #
    #   # Will generate the following in the final page...
    #   <html>
    #     <head>
    #       <script src="/javascripts/this.js" type="text/javascript"></script>
    #       <script src="/javascripts/something_else.js" type="text/javascript"></script>
    #       <link href="/stylesheets/that.css" media="all" rel="Stylesheet" type="text/css"/>
    #       <link href="/stylesheets/another_one.css" media="all" rel="Stylesheet" type="text/css"/>
    #     </head>
    #     .
    #     .
    #     .
    #   </html>
    #
    # See each method's documentation for more information.
    
    # :section: Bundling Asset Files
    # 
    # The key to making a fast web application is to reduce both the amount of
    # data transfered and the number of client-server interactions. While having
    # many small, module Javascript or stylesheet files aids in the development
    # process, your web application will benefit from bundling those assets in
    # the production environment.
    # 
    # An asset bundle is a set of asset files which are combined into a single
    # file. This reduces the number of requests required to render a page, and
    # can reduce the amount of data transfer required if you're using gzip
    # encoding.
    # 
    # Asset bundling is always enabled in production mode, and can be optionally
    # enabled in all environments by setting the <tt>:bundle_assets</tt> value
    # in <tt>config/merb.yml</tt> to +true+.
    # 
    # ==== Examples
    # 
    # In the development environment, this:
    # 
    #   js_include_tag :prototype, :lowpro, :bundle => true
    # 
    # will produce two <script> elements. In the production mode, however, the
    # two files will be concatenated in the order given into a single file,
    # <tt>all.js</tt>, in the <tt>public/javascripts</tt> directory.
    # 
    # To specify a different bundle name:
    # 
    #   css_include_tag :typography, :whitespace, :bundle => :base
    #   css_include_tag :header, :footer, :bundle => "content"
    #   css_include_tag :lightbox, :images, :bundle => "lb.css"
    # 
    # (<tt>base.css</tt>, <tt>content.css</tt>, and <tt>lb.css</tt> will all be
    # created in the <tt>public/stylesheets</tt> directory.)
    # 
    # == Callbacks
    # 
    # To use a Javascript or CSS compressor, like JSMin or YUI Compressor:
    # 
    #   Merb::Assets::JavascriptAssetBundler.add_callback do |filename|
    #     system("/usr/local/bin/yui-compress #{filename}")
    #   end
    #   
    #   Merb::Assets::StylesheetAssetBundler.add_callback do |filename|
    #     system("/usr/local/bin/css-min #{filename}")
    #   end
    # 
    # These blocks will be run after a bundle is created.
    # 
    # == Bundling Required Assets
    # 
    # Combining the +require_css+ and +require_js+ helpers with bundling can be
    # problematic. You may want to separate out the common assets for your
    # application -- Javascript frameworks, common CSS, etc. -- and bundle those
    # in a "base" bundle. Then, for each section of your site, bundle the
    # required assets into a section-specific bundle.
    # 
    # <b>N.B.: If you bundle an inconsistent set of assets with the same name,
    # you will have inconsistent results. Be thorough and test often.</b>
    # 
    # ==== Example
    # 
    # In your application layout:
    # 
    #   js_include_tag :prototype, :lowpro, :bundle => :base
    # 
    # In your controller layout:
    # 
    #   require_js :bundle => :posts
    
    # The require_js method can be used to require any JavaScript
    # file anywhere in your templates. Regardless of how many times
    # a single script is included with require_js, Merb will only include
    # it once in the header.
    #
    # ==== Examples
    #   <% require_js 'jquery' %>
    #   # A subsequent call to include_required_js will render...
    #   # => <script src="/javascripts/jquery.js" type="text/javascript"></script>
    #
    #   <% require_js 'jquery', 'effects' %>
    #   # A subsequent call to include_required_js will render...
    #   # => <script src="/javascripts/jquery.js" type="text/javascript"></script>
    #   #    <script src="/javascripts/effects.js" type="text/javascript"></script>
    #
    def require_js(*js)
      @required_js ||= []
      @required_js |= js
    end
    
    # The require_css method can be used to require any CSS
    # file anywhere in your templates. Regardless of how many times
    # a single stylesheet is included with require_css, Merb will only include
    # it once in the header.
    #
    # ==== Examples
    #   <% require_css('style') %>
    #   # A subsequent call to include_required_css will render...
    #   # => <link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css"/>
    #
    #   <% require_css('style', 'ie-specific') %>
    #   # A subsequent call to include_required_css will render...
    #   # => <link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css"/>
    #   #    <link href="/stylesheets/ie-specific.css" media="all" rel="Stylesheet" type="text/css"/>
    #
    def require_css(*css)
      @required_css ||= []
      @required_css |= css
    end
    
    # A method used in the layout of an application to create +<script>+ tags to include JavaScripts required in 
    # in templates and subtemplates using require_js.
    # 
    # ==== Options
    # bundle::  The name of the bundle the scripts should be combined into.
    #           If +nil+ or +false+, the bundle is not created. If +true+, a
    #           bundle named <tt>all.js</tt> is created. Otherwise,
    #           <tt>:bundle</tt> is treated as an asset name.
    # 
    # ==== Examples
    #   # my_action.herb has a call to require_js 'jquery'
    #   # File: layout/application.html.erb
    #   include_required_js
    #   # => <script src="/javascripts/jquery.js" type="text/javascript"></script>
    #
    #   # my_action.herb has a call to require_js 'jquery', 'effects', 'validation'
    #   # File: layout/application.html.erb
    #   include_required_js
    #   # => <script src="/javascripts/jquery.js" type="text/javascript"></script>
    #   #    <script src="/javascripts/effects.js" type="text/javascript"></script>
    #   #    <script src="/javascripts/validation.js" type="text/javascript"></script>
    #
    def include_required_js(options = {})
      return '' if @required_js.nil?
      js_include_tag(*(@required_js + [options]))
    end
    
    # A method used in the layout of an application to create +<link>+ tags for CSS stylesheets required in 
    # in templates and subtemplates using require_css.
    # 
    # ==== Options
    # bundle::  The name of the bundle the stylesheets should be combined into.
    #           If +nil+ or +false+, the bundle is not created. If +true+, a
    #           bundle named <tt>all.css</tt> is created. Otherwise,
    #           <tt>:bundle</tt> is treated as an asset name.
    # 
    # ==== Examples
    #   # my_action.herb has a call to require_css 'style'
    #   # File: layout/application.html.erb
    #   include_required_css
    #   # => <link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css"/>
    #
    #   # my_action.herb has a call to require_js 'style', 'ie-specific'
    #   # File: layout/application.html.erb
    #   include_required_css
    #   # => <link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css"/>
    #   #    <link href="/stylesheets/ie-specific.css" media="all" rel="Stylesheet" type="text/css"/>
    #
    def include_required_css(options = {})
      return '' if @required_css.nil?
      css_include_tag(*(@required_css + [options]))
    end
    
    # The js_include_tag method will create a JavaScript 
    # +<include>+ tag for each script named in the arguments, appending
    # '.js' if it is left out of the call.
    # 
    # ==== Options
    # bundle::  The name of the bundle the scripts should be combined into.
    #           If +nil+ or +false+, the bundle is not created. If +true+, a
    #           bundle named <tt>all.js</tt> is created. Otherwise,
    #           <tt>:bundle</tt> is treated as an asset name.
    # 
    # ==== Examples
    #   js_include_tag 'jquery'
    #   # => <script src="/javascripts/jquery.js" type="text/javascript"></script>
    #
    #   js_include_tag 'moofx.js', 'upload'
    #   # => <script src="/javascripts/moofx.js" type="text/javascript"></script>
    #   #    <script src="/javascripts/upload.js" type="text/javascript"></script>
    #
    #   js_include_tag :effects
    #   # => <script src="/javascripts/effects.js" type="text/javascript"></script>
    #
    #   js_include_tag :jquery, :validation
    #   # => <script src="/javascripts/jquery.js" type="text/javascript"></script>
    #   #    <script src="/javascripts/validation.js" type="text/javascript"></script>
    #
    def js_include_tag(*scripts)
      options = scripts.last.is_a?(Hash) ? scripts.pop : {}
      return nil if scripts.empty?
      
      if (bundle_name = options[:bundle]) && Merb::Assets.bundle? && scripts.size > 1
        bundler = Merb::Assets::JavascriptAssetBundler.new(bundle_name, *scripts)
        bundled_asset = bundler.bundle!
        return js_include_tag(bundled_asset)
      end

      tags = ""

      for script in scripts
        attrs = {
          :src => asset_path(:javascript, script),
          :type => "text/javascript"
        }
        tags << %Q{<script #{attrs.to_xml_attributes}>//</script>}
      end

      return tags
    end
    
    # The css_include_tag method will create a CSS stylesheet 
    # +<link>+ tag for each stylesheet named in the arguments, appending
    # '.css' if it is left out of the call.
    # 
    # ==== Options
    # bundle::  The name of the bundle the stylesheets should be combined into.
    #           If +nil+ or +false+, the bundle is not created. If +true+, a
    #           bundle named <tt>all.css</tt> is created. Otherwise,
    #           <tt>:bundle</tt> is treated as an asset name.
    # media::   The media attribute for the generated link element. Defaults
    #           to <tt>:all</tt>.
    #
    # ==== Examples
    #   css_include_tag 'style'
    #   # => <link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css" />
    #
    #   css_include_tag 'style.css', 'layout'
    #   # => <link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css" />
    #   #    <link href="/stylesheets/layout.css" media="all" rel="Stylesheet" type="text/css" />
    #
    #   css_include_tag :menu
    #   # => <link href="/stylesheets/menu.css" media="all" rel="Stylesheet" type="text/css" />
    #
    #   css_include_tag :style, :screen
    #   # => <link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css" />
    #   #    <link href="/stylesheets/screen.css" media="all" rel="Stylesheet" type="text/css" />
    # 
    #  css_include_tag :style, :media => :print
    #  # => <link href="/stylesheets/style.css" media="print" rel="Stylesheet" type="text/css" />
    def css_include_tag(*stylesheets)
      options = stylesheets.last.is_a?(Hash) ? stylesheets.pop : {}
      return nil if stylesheets.empty?
      
      if (bundle_name = options[:bundle]) && Merb::Assets.bundle? && stylesheets.size > 1
        bundler = Merb::Assets::StylesheetAssetBundler.new(bundle_name, *stylesheets)
        bundled_asset = bundler.bundle!
        return css_include_tag(bundled_asset)
      end

      tags = ""

      for stylesheet in stylesheets
        attrs = {
          :href => asset_path(:stylesheet, stylesheet),
          :type => "text/css",
          :rel => "Stylesheet",
          :media => options[:media] || :all
        }
        tags << %Q{<link #{attrs.to_xml_attributes} />}
      end

      return tags
    end
    
    # :section: Caching
    # ViewContextMixin provides views with fragment caching facilities.
    
    # The cache method is a simple helper method
    # for caching template fragments.  The value of the supplied
    # block is stored in the cache and identified by the string
    # in the +name+ argument.
    #
    # ==== Example
    #   <h1>Article list</h1>
    #
    #   <% cache(:article_list) do %>
    #     <ul>
    #     <% @articles.each do |a| %>
    #       <li><%= a.title %></li>
    #     <% end %>
    #     </ul>
    #   <% end %>
    #
    # See the documentation for Merb::Caching::Fragment for more
    # information.
    #
    def cache(name, &block)
      return block.call unless caching_enabled?
      buffer = eval("_buf", block.binding)
      if fragment = ::Merb::Caching::Fragment.get(name)
        buffer.concat(fragment)
      else
        pos = buffer.length
        block.call
        ::Merb::Caching::Fragment.put(name, buffer[pos..-1])
      end
    end
  
    # Calling throw_content stores the block of markup for later use.
    # Subsequently, you can make calls to it by name with <tt>catch_content</tt>
    # in another template or in the layout. 
    # 
    # Example:
    # 
    #   <% throw_content :header do %>
    #     alert('hello world')
    #   <% end %>
    #
    # You can use catch_content :header anywhere in your templates.
    #
    #   <%= catch_content :header %>
    #
    # You may find that you have trouble using thrown content inside a helper method
    # There are a couple of mechanisms to get around this.
    # 
    # 1. Pass the content in as a string instead of a block
    # 
    # Example: 
    #  
    #   throw_content(:header, "Hello World")
    #
    def throw_content(name, content = "", &block)
      content << capture(&block) if block_given?
      controller.thrown_content[name] << content
    end
    
    # Concat will concatenate text directly to the buffer of the template.
    # The binding must be supplied in order to obtian the buffer.  This can be called directly in the 
    # template as 
    # concat( "text", binding )
    #
    # or from a helper method that accepts a block as
    # concat( "text", block.binding )
    def concat( string, binding )
      _buffer( binding ) << string
    end
    
    # Creates a generic HTML tag. You can invoke it a variety of ways.
    #   
    #   tag :div
    #   # <div></div>
    #   
    #   tag :div, 'content'
    #   # <div>content</div>
    #   
    #   tag :div, :class => 'class'
    #   # <div class="class"></div>
    #   
    #   tag :div, 'content', :class => 'class'
    #   # <div class="class">content</div>
    #   
    #   tag :div do
    #     'content'
    #   end
    #   # <div>content</div>
    #   
    #   tag :div, :class => 'class' do
    #     'content'
    #   end
    #   # <div class="class">content</div>
    # 
    def tag(name, contents = nil, attrs = {}, &block)
      attrs = contents if contents.is_a?(Hash)
      contents = capture(&block) if block_given?
      open_tag(name, attrs) + contents.to_s + close_tag(name)
    end
    
    # Creates the opening tag with attributes for the provided +name+
    # attrs is a hash where all members will be mapped to key="value"
    #
    # Note: This tag will need to be closed
    def open_tag(name, attrs = nil)
      "<#{name}#{' ' + attrs.to_html_attributes if attrs && !attrs.empty?}>"
    end
    
    # Creates a closing tag
    def close_tag(name)
      "</#{name}>"
    end
    
    # Creates a self closing tag.  Like <br/> or <img src="..."/>
    #
    # +name+ : the name of the tag to create
    # +attrs+ : a hash where all members will be mapped to key="value"
    def self_closing_tag(name, attrs = nil)
      "<#{name}#{' ' + attrs.to_html_attributes if attrs && !attrs.empty?}/>"
    end
  end
end
