module Merb
  module Test
    module MarkupMatchers
      class HaveSelector
        def initialize(expected)
          @expected = expected
        end
    
        def matches?(stringlike)
          @document = case stringlike
          when Hpricot::Elem
            stringlike
          when StringIO
            Hpricot.parse(stringlike.string)
          else
            Hpricot.parse(stringlike)
          end
          !@document.search(@expected).empty?
        end
    
        def failure_message
          "expected following text to match selector #{@expected}:\n#{@document}"
        end

        def negative_failure_message
          "expected following text to not match selector #{@expected}:\n#{@document}"
        end
      end
  
      class MatchTag
        def initialize(name, attrs)
          @name, @attrs = name, attrs
          @content = @attrs.delete(:content)
        end

        def matches?(target)
          @errors = []
          unless target.include?("<#{@name}")
            @errors << "Expected a <#{@name}>, but was #{target}"
          end
          @attrs.each do |attr, val|
            unless target.include?("#{attr}=\"#{val}\"")
              @errors << "Expected #{attr}=\"#{val}\", but was #{target}"
            end
          end
          if @content
            unless target.include?(">#{@content}<")
              @errors << "Expected #{target} to include #{@content}"
            end
          end
          @errors.size == 0
        end
    
        def failure_message
          @errors[0]
        end
    
        def negative_failure_message
          "Expected not to match against <#{@name} #{@attrs.map{ |a,v| "#{a}=\"#{v}\"" }.join(" ")}> tag, but it matched"
        end
      end
  
      class NotMatchTag
        def initialize(attrs)
          @attrs = attrs
        end
    
        def matches?(target)
          @errors = []
          @attrs.each do |attr, val|
            if target.include?("#{attr}=\"#{val}\"")
              @errors << "Should not include #{attr}=\"#{val}\", but was #{target}"
            end
          end
          @errors.size == 0
        end
    
        def failure_message
          @errors[0]
        end
      end
  
      def match_tag(name, attrs={})
        MatchTag.new(name, attrs)
      end
      def not_match_tag(attrs)
        NotMatchTag.new(attrs)
      end
  
      def have_selector(expected)
        HaveSelector.new(expected)
      end
      alias_method :match_selector, :have_selector
      
      
    end
  end
end