class ThreadedCommentsLinkRenderer < WillPaginate::LinkRenderer

  def to_html
    html = page_link_or_nil(@collection.next_page, 'next', @options[:next_label])
    @options[:container] ? @template.content_tag(:ul, html, html_attributes) : html
  end

protected

  def page_link_or_nil(page, span_class, text = nil)
    text ||= page.to_s
    if page && page != current_page
      page_link(page, text, :class => span_class)
    end
  end

  def page_link(page, text, attributes = {})
    @template.content_tag(:span, @template.link_to(text, "#", attributes.merge(:class => 'comment_link', :page => page)))
  end
end