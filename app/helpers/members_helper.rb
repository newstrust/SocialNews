module MembersHelper
  
  def first_name(member)
    member.first_name
  end

  def privacy_pull_down_menu(member)
    opts = pull_down_menu("member_privacy")
    if member.is_student?
      opts + [["Only Me", Member::Visibility::PRIVATE]]
    else
      opts
    end
  end

  # If member.status is duplicate, and the override_hidden flag is set, then we can link to their name. Currently only true for the
  # member name in the upper right of every page
  def link_to_member(member, link_options={}, opts={})
    opts[:absolute_urls] ||= false
    opts[:newsletter] ||= false
    link_options[:class] ||= ""
    link_options[:class] += "#{popup_check}"
    link_text = link_options[:link_text] || member.display_name
    return (member.is_visible? || (["duplicate","guest"].include?(member.status) && link_options[:override_hidden])) ?
      link_to(s(link_text), opts[:absolute_urls] ? member_url(member) : member_path(member), link_options) :
      content_tag(:strong, s(link_text))
  end
  
  def member_photo(member, opts={})
    opts[:style] ||= ""
    return image_tag((member.image ? member.image.public_filename(:thumb) : "/images/ui/silhouette_sml.jpg"), :size => "40x40", :alt => member.name, :title => member.name, :style => opts[:style])
  end
  
  def link_to_member_photo(member, link_options={}, opts={})
    opts[:style] ||= ""
    opts[:newsletter] ||= false
    return (member.is_visible? || (["duplicate","guest"].include?(member.status) && link_options[:override_hidden])) ? link_to(member_photo(member, :style => opts[:style]), member, link_options) : member_photo(member, :style => opts[:style])
  end

  def session_member_is_owner?(owner)
    logged_in? && current_member == owner
  end

  def session_member_is_owner_or_has_role_or_above?(owner, role)
    logged_in? && ((current_member == owner) || current_member.has_role_or_above?(role))
  end

  # can use this to determine if their MyNews RSS should be public. Means anyone can view this page if true
  def is_public_mynews?(member)
    # SSS FIXME: Bad attribute name -- probably repurposed from when it used to be a boolean?
    member.public_mynews == 'public'
  end
  
  # checks viewing member status as well as target member's settings. Don't use this for RSS feed.
  def is_visible_mynews?(member)
    member.is_visible? && (member.public_mynews == 'public' || (logged_in? && (!member.public_mynews || member.public_mynews == 'members'))) || session_member_is_owner_or_has_role_or_above?(member,:admin)
  end

  def process_email_template(template, recipient, freq = Newsletter::BULK, local_site = nil)
    x = template.clone
    x.gsub!("[DOMAIN]",            local_site ? local_site.home_page : LocalSite.national_site)
    x.gsub!("[MEMBER.NAME]",       recipient.name)
    x.gsub!("[MEMBER.FIRST_NAME]", recipient.name.split("\s").first)
    x.gsub!("[MEMBER.LAST_NAME]",  recipient.name.split("\s").last) ## FIXME: What if a member has only one name?  This replaces it with the first name
    x.gsub!("[MEMBER.EMAIL]",      recipient.email)
    x.gsub!("[MEMBER.REINVITE_LINK]", "#{activate_members_url}/#{recipient.activation_code}")
    x.gsub!("[UNSUBSCRIBE_URL]", newsletter_unsubscribe_url(:freq => freq, :key => recipient.newsletter_unsubscribe_key(self)))

    return x
  end

  def freq_name(freq)
    (freq == Newsletter::BULK ? "Special Notices" : freq.humanize)
  end

  def process_member_refs(member_refs)
    if (member_refs.nil? || member_refs.strip.length == 0)
      raise "No email ids or member names provided! Try again!"
    else
      notices = ""
      processed_members = Array.new
      member_array = member_refs.split("\n")
      member_array.each { |mref|
        begin
          mref.strip!
          next if (mref == "")

          m = (mref =~ /\@/) ? Member.find_by_email(mref) : Member.find_by_name(mref)
          if m.nil?
            notices += "No member found for #{mref}<br>"
          elsif !processed_members[m.id]  # No duplicates!
            # Now, let the caller do whatever they want
            processed_members[m.id] = true
            yield m, mref 
          end
        rescue Exception => e
          logger.error "Exception: #{e}"
          notices += "Exception '#{e}' while processing #{mref}<br>"
        end
      }
      return notices
    end
  end
  
  # Member Profile formatters
  #
  
  # make sure member home page works even if they didn't add http:// in front
  def add_http(url)
    return 'http://' + url.sub(/http:\/\//,'')
  end

  def format_url(url, key)
    stripped_url = url.sub(/http:\/\//,'')
    link_to stripped_url, 'http://' + stripped_url, :target => "_blank"
  end
  
  def format_fb_profile_url(fb_uid, key)
    fb_url = "http://www.facebook.com/profile.php?id=#{fb_uid}"
    link_to "Facebook Profile", fb_url
  end

  # list all affiliated sources
  def affiliated_sources(loc, key)
    @member.affiliated_sources.collect{|as| 
      (['list', 'feature'].include?(as.status)) ? link_to(as.name, as) : as.name
    }.join(", ")
  end

  # list all favorite tags/topics
  def favorite_tags(loc, key)
    @member.favorite_tags.collect{|ft| 
      (['Topic', 'Subject'].include?(ft.tag_type.to_s)) ? link_to(ft.name, Topic.tagged_topic_or_subject(ft)) : ft.name
    }.join(", ")
  end

  # list all hosted topics
  def hosted_topics(loc, key)
     @member.hosted_topics.collect{|ht| link_to(ht.name, ht)}.join(", ")
  end

  # list all hosted sources
  def hosted_sources(loc, key)
     @member.hosted_sources.collect{|hs| link_to(hs.name, hs)}.join(", ")
  end


  # used specifically to display the list of favorite links on member profile
  # Format: URL Description
  # if there's no description, then just display the URL as a link
  def format_links(links_blob, key)
    links = ""
    crlf = "\r\n"
    link_line = links_blob.squeeze(" ").split(crlf)
    link_line.each do |this_link|
      link_url = this_link.split(' ',2)
      # was the leading http:// left out? If so, add it back in
      if link_url[0] && !/^http:\/\//i.match(link_url[0])
        link_url[0] = 'http://' + link_url[0]
      end
      # if there's a description, then link to it
      if link_url[1] && link_url[1] != ""
        links += link_to link_url[1], link_url[0] 
        links += '<br>'
      elsif link_url[0]        # skip if there was a blank line
        links += format_url link_url[0], ""
        links += '<br>'
      end
    end
    return links
  end


  # used to display the Location info on the member profile page
  # Format: city, state, country
  def format_member_location(loc, key)

    # if it's "n/a" then don't display here
    if loc == "n/a"
      return ""
    elsif key == "city"
        return loc
    elsif key == "state"
      humanize_token_direct("states",loc)
    elsif key == "country"
      humanize_token_direct("countries",loc)
    end
  end

  # Helper to wrap the signup form inside an invitation template
  def wrap_inside_landing_page_template(&block)
    wrap_template(:landing_page_template, &block)
  end
  
  # Helper to wrap the welcome page form for invitations
  def wrap_inside_welcome_page_template(&block)
    wrap_template(:welcome_page_template, &block)
  end  
  
  # Helper to wrap the signup form inside an invitation template
  def wrap_inside_success_page_template(&block)
    if @invitation # Only wrap if we are processing an invitation. 
      wrap_template(:success_page_template, &block)
    else
      concat(capture(&block))
    end
  end

  def wrap_template(template, &block)
    content = ''
    body = capture(&block)
    if @invitation
      content << process_template_macros(attr_with_erb_to_html(@invitation, template), body)
    else 
      content << body
    end
    concat(content)
  end

  # feed links
  def member_rss_icon(url, html_options={})
    return link_to(image_tag('/images/ui/rss-12x12.jpg', html_options.merge(:size => "12x12", :alt => "Member RSS Feed", :title => "Member RSS Feed")), url)
  end

  def member_activity_line(obj, member, story_flags)
    t = obj.class == Review ? obj.updated_at : obj.created_at # Reviews use updated_at time because they can be edited several times
    "<div class='activity_meaning'>#{first_name(member)} #{[:posted, :reviewed, :starred].collect { |f| story_flags[f] ? "<span class='green'>#{f.to_s}</span>" : nil}.compact * " and "} this story - #{t.strftime('%b %e, %Y')}</div>"
  end
end
