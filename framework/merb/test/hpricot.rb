# http://yehudakatz.com/2007/01/27/a-better-assert_select-assert_elements/
# based on assert_elements
# Author: Yehuda Katz
# Email:  wycats @nospam@ gmail.com
# Web:    http://www.yehudakatz.com
#
# which was based on HpricotTestHelper
# Author: Luke Redpath
# Email: contact @nospam@ lukeredpath.co.uk
# Web: www.lukeredpath.co.uk / opensource.agileevolved.com

require 'hpricot'

class Hpricot::Elem
  def should_contain(value)
    self.inner_text.include?(value)
  end

  def should_match(regex)
    self.inner_text.match(regex)
  end
  
  # courtesy of 'thomas' from the comments
  # of _whys blog - get in touch if you want a better credit!
  def inner_text
    self.children.collect do |child|
      child.is_a?(Hpricot::Text) ? child.content : ((child.respond_to?("inner_text") && child.inner_text) || "")
    end.join.strip
  end
end

module HpricotTestHelper
  # returns the inner content of
  # the first tag found by the css query
  def tag(css_query)
    process_output
    @output.content_for(css_query)
  end
  
  # returns an array of tag contents
  # for all of the tags found by the
  # css query
  def tags(css_query)
    process_output
    @output.content_for_all(css_query)
  end
  
  # returns a raw Hpricot::Elem object
  # for the first result found by the query
  def element(css_query)
    process_output
    @output[css_query].first
  end
  
  # returns an array of Hpricot::Elem objects
  # for the results found by the query
  def elements(css_query)
    process_output
    Hpricot::Elements[*css_query.split(",").map(&:strip).map do |query|
      @output[query]
    end.flatten]
  end
  
  def get_elements css_query, text
    els = elements(css_query)
    case text
      when String then els.reject! {|t| !t.should_contain(text) }
      when Regexp then els.reject! {|t| !t.should_match(text) }
    end
    els
  end
  
  def assert_elements css_query, equality = nil, &block
    message = equality.delete(:message) if equality.is_a?(Hash)

    case equality
      when Numeric then equality = {:count => equality}
      when Range then equality = {:minimum => equality.to_a.first, :maximum => equality.to_a.last }
      else equality ||= {}
    end
    
    equality.merge!({:minimum => 1}) if (equality.keys & [:minimum, :maximum, :count]).empty?
    
    els = get_elements(css_query, equality[:text])

    ret = equality.keys.include?(:minimum) ? (els.size >= equality[:minimum]) : true 
    ret &&= (els.size <= equality[:maximum]) if equality.keys.include?(:maximum)
    ret &&= (els.size == equality[:count]) if equality.keys.include?(:count)
    
    if block && !els.empty?
      ret &&= self.dup.instance_eval do
        @output = HpricotTestHelper::DocumentOutput.new(els.inner_html)
        @block = true 
        instance_eval(&block)
      end
    end
    
    if(equality[:count] != 0)
      assert ret, "#{ message } \"#{ css_query }\" with \"#{ equality.inspect }\" was not found."
    else
      assert ret, "#{ message } \"#{ css_query }\" with \"#{ equality.reject{|k,v| k == :count}.inspect }\" was found, but you specified :count => 0."
    end
    ret
  end
  
  # small utility class for working with
  # the Hpricot parser class
  class DocumentOutput
    def initialize(response_body)
      @parser = Hpricot.parse(response_body)
    end

    def content_for(css_query)
      @parser.search(css_query).first.inner_text
    end

    def content_for_all(css_query)
      @parser.search(css_query).collect(&:inner_text)
    end

    def [](css_query)
      @parser.search(css_query)
    end
  end
  
  protected
    # creates a new DocumentOutput object from the response
    # body if hasn't already been created. This is
    # called automatically by the element and tag methods
    def process_output
      if !@block && (@output.nil? || (@controller.body != @response_output))
        @output = HpricotTestHelper::DocumentOutput.new(@controller.body)
        @response_output = @controller.body  
      end
    end
end