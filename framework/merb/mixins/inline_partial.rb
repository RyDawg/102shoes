module Merb::InlinePartialMixin
  def partial(template, opts={})

    unless @_template_format
      @web_controller.choose_template_format(Merb.available_mime_types, {})
    end

    found_template = @web_controller._cached_partials["#{template}.#{@_template_format}"] ||=
      @web_controller.send(:find_partial, template, opts)

    template_method = found_template && found_template.gsub(/[^\.a-zA-Z0-9]/, "__").gsub(/\./, "_")

    unless template_method && self.respond_to?(template_method)
      return super
    end

    if with = opts.delete(:with)
      as = opts.delete(:as) || found_template.match(/(.*\/_)([^\.]*)/)[2]
      @_merb_partial_locals = opts
      sent_template = [with].flatten.map do |temp|
        @_merb_partial_locals[as.to_sym] = temp
        send(template_method)
      end.join
    else
      @_merb_partial_locals = opts        
      sent_template = send(template_method)
    end

    return sent_template if sent_template

  end      
end
