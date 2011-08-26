module FormHelper
  # Form buttons; if no URL, then submit the form the button belongs to.
  # Otherwise, follow link. CSS differs for each, too.
  def submit_button(text, url=nil, options={})
    options.merge!(:class => "submit_btn")
    debounce = options[:debounce] || true
    if url
      return link_to("", url, options)
    else
      return link_to_function("", "submit_form_button(this, #{debounce})", options)
    end
  end

  # batch_autocomplete & assoc taxonomy json methods
  def batch_autocomplete(param_array_prefix, association, options={})
    options[:param_array_prefix] = param_array_prefix
    options[:div_id] = param_array_prefix.gsub(/[\[\]]/, "_")
    options[:current_associations] = association.map{|a| {:id => a.id, :name => a.name}}
    options[:association_params] ||= {}
    render :partial => 'shared/batch_autocomplete', :locals => options
  end

# SSS: Now the taxonomy info is coming from standalone json files which are regularly updated
  def source_taxonomy
    "source_taxonomy"
  end

  def topic_taxonomy
    "topic_taxonomy"
  end
end
