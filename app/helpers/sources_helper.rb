module SourcesHelper
  MAX_AGGREGATE_DATA = 15
  
  def source_favicon(source)
    favicon = source ? source.favicon : nil
    "<span class='favicon' style='background-image:url(#{favicon.blank? ? "/images/ui/source_favicon.png" : favicon});'></span>"
  end

  def link_to_source(source, options = {}, show_favicon = true, followed = {})
    return "Unknown Source" if source.nil?
    followed[:sources] ||= []
    mynews_class = followed[:sources].include?(source) ? (options[:mynews_info_hidden] ? " following_off": " following") : ""
    formatting_options = {:class => "pubname" + popup_check + mynews_class}.merge(options)
    favicon = show_favicon ? source_favicon(source) : ""
    if source.is_public?
      s_url = options[:ref].blank? ? source_path(source) : source_path(source, options.slice(:ref))
      favicon + link_to(s(source.name), s_url, formatting_options) 
    else
      content_tag("span", favicon + s(source.name), formatting_options)
    end
  end

  def link_to_sources(sources, options = {}, hide_favicons = false, followed = {})
    return link_to_source(nil) if sources.empty?
    i = hide_favicons ? 1 : 0 # count the number of links, pass to link_to_source so it shows only 1 favicon, or none if hidden flag
    return sources.collect{ |s| link_to_source(s, options, (i+=1) == 1, followed)}.join(", ")
  end
  
  def sources_length(sources)
    return 0 if sources.empty?
    len = (sources.length - 1) * 2  # include count for comma and space between sources
    sources.collect{ |s| len += s.name.length }
    return len
  end

  # pass in a list of source IDs, display source favicon, link, and trustometer
  def show_source_list(source_array,show_ownership=false)
     source_list = ""
     source_array.each do |s|
      source = Source.exists?(s) ? Source.find(s) : nil
      if !source.nil? 
        source_list += "<div class=\"overview_entry\">#{show_ownership ? "<span class=\"pubownership\">(" + source.ownership + ")</span>" : ""}#{link_to_source(source)}</div>" 
      elsif (s==0)
        source_list += "<div class=\"overview_entry\"></div>" 
      end
    end
    return source_list
  end

  # Source Profile formatters

  def format_aggregate_info(aggregate_info, key, num_items=MAX_AGGREGATE_DATA, show_story_counts=true)
    append_info = ""
    if key == "top_authors" && !@source.journalist_names_featured.blank?
      append_info = display_partial_list(@source.journalist_names_featured, num_items) + " | "
    end

    body = aggregate_info.slice(0, num_items).collect do |st|
      name = st[0]
      if name
        name = name.humanize if key == "top_formats"
        name = name.titleize if key != "top_topics"
        num_entries = st[1]
        show_story_counts ? "#{name} <span class=\"editorial_gray\">(#{num_entries})</span>" : "#{name}"
      end
    end.compact.join(", ") + (aggregate_info.size > num_items ? "..." : "")
  end
  
  def format_source_owners(owners, key)
    if key == "source_managers"
      "Managers: " + display_partial_list(owners,5)
    else
      owners
    end
  end

  def format_authors(authors, key)
    display_partial_list(authors, 10)
  end

  # TODO: remove lower case on language.
  def format_source_audience(audience, key)
    return "" if audience.blank?

    if key == "source_audience_size"
      desc = humanize_token_direct("source_audience_size", audience).split("(")
      return desc[0] + '<span class="editorial_gray">(' + desc[1] + '</span>'
    elsif key == "source_language"
      return "(" + humanize_token_direct("source_language", audience.downcase) + ")"
    end
  end

  # TODO: separator between the media/source_media_other* and source_type* should be |
  def format_source_media_types(media_type, key)
    return "" if media_type.blank?

    if key.match("media")
      humanize_token_direct("source_media",media_type)
    elsif key.match("type")
      humanize_token_direct("source_type",media_type)
    end
  end

  def format_contact_info(contact, key)
    return "" if contact.blank?

    if key == "source_web_contact_address"
      link_to "Contact Web Form", contact
    elsif key == "source_public_email_address"
      mail_to contact, contact, :encode => "javascript"
    elsif logged_in? and (current_member.has_role_or_above?(:staff) || (@source.contact_source_status == "list" && current_member.has_role_or_above?(:host)))
      if key == "source_representative_name"
        return "Representative: " + contact
      elsif key == "source_representative_email"
        mail_to contact, contact, :encode => "javascript"
      else
        contact
      end
    end
  end
  
  
  # used to display the address info for a source
  # Format: don't display any field that is set to "n/a"
  def format_source_location(loc, key)
    # if it's "n/a" then don't display here
    if loc.blank? || loc == "n/a"
      return ""
    end
    if key == "source_country"
      country = flip_first_last_name(humanize_token_direct("countries",loc))
      if country == "United States"
        country = "US"
      end
      return country
    else
      loc
    end
  end



end
