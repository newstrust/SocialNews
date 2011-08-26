module Admin::AdminHelper
  def form_input(form_obj, opts)
    buf = case opts[:type]
      when nil          then form_obj.text_field opts[:attr]
      when "text_field" then form_obj.text_field opts[:attr]
      when "text_area"  then form_obj.text_area opts[:attr]
      when "dropdown"   then form_obj.select opts[:attr], opts[:sel_opts], :include_blank => opts[:include_blank]
      when "checkbox"   then form_obj.check_box opts[:attr]
      when "file"       then form_obj.file_field opts[:attr]
      when "hidden"     then form_obj.hidden_field opts[:attr], :value => opts[:value]
    end
    buf
  end

  def form_field(form_obj, opts)
    buf = <<OUT
    <div class="form_field#{opts[:class] ? ' ' + opts[:class] : ''}"#{" style='#{opts[:style]}'" if opts[:style]}>
      #{'<div class="hint">' + opts[:hint] + '</div>' if !opts[:hint].blank?}
      #{('<label for=' + opts[:attr].to_s + '">' + (opts[:name] || opts[:attr].to_s.humanize) + '</label>') if opts[:type] != "hidden"}
      #{form_input(form_obj, opts)}
    </div>
OUT
  end

  def add_button(path, text = nil, tool_tip = 'Add')
    link_to("#{text} #{image_tag('icons/add.png', :alt => 'Add', :title => tool_tip)}", path, :method => :post)
  end

  def edit_button(path, text = nil, tool_tip = 'Edit')
    link_to("#{text} #{image_tag('icons/pencil.png', :alt => 'Edit', :title => tool_tip)}", path)
  end
  
  def delete_button(path, text = nil, tool_tip = 'Delete')
    link_to("#{text} #{image_tag('icons/delete.png', :alt => 'Delete', :title => tool_tip)}", path, :method => :delete, :confirm => 'Are you sure you want to delete this?')
  end

  def cancel_button(text, url, options={})
    link_to(text, url, options)
  end

  def form_buttons(text, cancel_path, opts={})
    "<div class='buttons'#{" style='#{opts[:style]}'" if !opts[:style].blank?}> #{submit_tag text} #{cancel_tag cancel_path} </div>"
  end
end
