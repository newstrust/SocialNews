require 'system_timer'
require 'will_paginate'

module ApplicationHelper
  include Sanitize
  include ActionView::Helpers::SanitizeHelper
  extend ActionView::Helpers::SanitizeHelper::ClassMethods

  APP_SLUG = SocialNewsConfig["app"]["slug"]
  APP_NAME = SocialNewsConfig["app"]["name"]

  def app_slug
    APP_SLUG
  end

  def app_name
    APP_NAME
  end

  def email_addr(category)
    SocialNewsConfig["email_addrs"][category]
  end

  def facebook_enabled?
    @@fbc_enabled ||= (SocialNewsConfig["fbc"] && (SocialNewsConfig["fbc"]["enabled"].to_i == 1))
  end

  # Creates a Cancel button linked to url
  def cancel_tag(url, options = {})
    link_to((tag :input, { "type" => "button", "value" => "Cancel"}.update(options.stringify_keys)), url, :style => "text-decoration: none;")
  end

  def external_link(text, url, options={})
    link_to(text, url, options.merge(:target => "_blank"))
  end

  def layout_partial(local_site, template)
    if local_site
      template_dir = "layouts/local_sites/#{local_site.slug}/"
      File.exists?("#{RAILS_ROOT}/app/views/#{template_dir}_#{template}.html.erb") ? template_dir + template : "layouts/#{template}"
    else
      "layouts/#{template}"
    end
  end

  def rand_sort_value; n = rand(11); n == 5 ? 0 : (n < 5 ? -1 : 1); end

  def tag_path(t)
    t.class == Topic ? topic_path(t) : "/#{t.slug}"
  end
  
  def user_has_ie6?
    request.user_agent =~ /MSIE [1-6]/ && request.user_agent !~ /MSIE (7|8)/
  end

  def fb_connected_and_linked
    current_member.fbc_linked? && facebook_session
  end

  def publishable_via_fb_connect
    # SSS: Now, Facebook lets us invoke the stream publishing call even without being connected, or even without having a valid fb session!
    facebook_enabled?
  end

  def fb_login_button(onlogin_action="fbc_login()", opts={})
    opts["show-faces"] ||= false
    opts["onlogin"]    ||= onlogin_action

    "<fb:login-button #{opts.collect { |k,v| "#{k}=\"#{v}\"" }.join(" ")}></fb:login-button>"
  end

  def facebook_session
    @fb_info ||= FacebookConnectSettings.get_user_info_from_cookies(cookies)
  end

  def current_facebook_user
    if !@curr_fb_user
      at = FacebookConnectSettings.get_access_token(cookies)
      if at
        client = Koala::Facebook::API.new(at)
        @curr_fb_user = client.get_object("me")
      end
      @curr_fb_user ||= {}
    end
    @curr_fb_user.blank? ? nil : @curr_fb_user
  rescue Exception => e
    nil
  end

  # see session call in ApplicationController
  # session is an empty hash if disabled, otherwise CGI::Session (or ActionController::TestSession in tests)
  def visitor_is_bot?
    # !session_enabled? # not available in helper logic
    session.class == Hash
  end

  def sharable_story_url(story, opts={})
    (story.from_framebuster_site? || user_has_ie6? || story.is_pdf?) ? story_url(story, opts) : toolbar_story_url(story, opts)
  end

  def share_link(story, css_class=nil, link_text="Share")
    link_to link_text, "#", :onclick => "return addthis_open(this, '', '#{sharable_story_url(story)}', '#{escape_javascript(story.title)}');", :onmouseout => "addthis_close()", :class => css_class, :title => "Share this story"
  end

  # http://wiki.developers.facebook.com/index.php/Facebook_Share
  def fb_share_link(url, opts={})
    opts[:type] ||= "icon"
    "<fb:share-button href='#{url}' class='url' type='#{opts[:type]}'></fb:share-button>"
  end

  # http://developers.facebook.com/docs/reference/plugins/like
  def fb_like_link(url, opts={})
    opts[:show_faces] ||= false
    opts[:width] ||= 20
    opts[:layout] ||= "standard"
    opts[:data_send] ||= false
    "<fb:like href='#{url}' data-send='#{opts[:data_send] ? 'true' : 'false'}' layout='#{opts[:layout]}' show_faces='#{opts[:show_faces]}' width='#{opts[:width]}'></fb:like>"
  end

  # http://developers.facebook.com/docs/reference/plugins/like
  def fb_like_iframe(url_or_story_obj, opts={})
    opts[:layout] ||= "standard"
    opts[:show_faces] ||= "false"
    opts[:width] ||= "80"
    opts[:height] ||= "24"
    opts[:type] ||= ""
    url = (opts[:type] == "story") ? story_url(url_or_story_obj) : url_or_story_obj
    padding_top = opts[:layout] == "standard" ? 0 : 1
   # unless opts[:width].to_i <= 53 && (client_browser_version == "MSIE7" || client_browser_version == "MSIE6")	# until fb ie7 bug fixed, don't display with cropped iframe
  		"<iframe src=\"http://www.facebook.com/plugins/like.php?href=#{url}&layout=#{opts[:layout]}&show_faces=#{opts[:show_faces]}&width=#{opts[:width]}&action=like&font&colorscheme=light&height=#{opts[:height]}\" scrolling=\"no\" frameborder=\"0\" style=\"border:none; overflow:hidden; width:#{opts[:width]}px; height:#{opts[:height]}px;margin-right:6px;padding-top:#{padding_top}px;float:left\" allowTransparency=\"true\"></iframe>"
  #	end
  end

  def tweet_page(page_url_or_story_obj, opts={})
    opts[:type] ||= ""
    return tweet_story(page_url_or_story_obj, opts) if opts[:type] == "story"

    page_url = page_url_or_story_obj

    link_text  = opts[:link_text] || ""
    css_class  = opts[:class] || "twitter_icon"
    title      = opts[:title] || "Tweet this page"
    tweet_text = opts[:tweet_text] || "Check out this page on #{SocialNewsConfig["app"]["twitter"]}"
    if logged_in?
      link_to_function(link_text, "tweet_page(this, {tweet_text: '#{escape_javascript(tweet_text)}', url: '#{page_url}'})", :class => css_class, :title => title)
    else
      if opts[:toolbar]
        link_to_function opts[:link_text], "show_popdown_form('log_in')", :id => "nav_login", :class => css_class, :title => "Login to #{SocialNewsConfig["app"]["name"]} to tweet about this page"
      else
        link_to(link_text, new_sessions_path, :class => css_class, :title => "Login to #{SocialNewsConfig["app"]["name"]} to tweet about this page")
      end
    end
  end

  def tweet_story(story, opts={})
    opts[:link_text] ||= ""
    opts[:class] ||= "twitter_icon"

    # 1. If logged in, do the regular API thing -- bit.ly is hit via ajax on demand
    # 2. If not (logged in or twitter connected) and we are on the toolbar, go to twitter with status box pre-filled -- fetch a short url from bit.ly if required, this potentially slows down toolbar rendering for the first guest user
    # 3. If not on the toolbar and not logged in, present a login form
    # FIXME: 2,3 should be merged into behavior of 2, but without eager bit.ly hits so that a story listing page with 20 stories doesn't hit bit.ly 20 times for all stories before rendering the page.

    if logged_in?
      link_to_function(opts[:link_text], "tweet_story(this, {id: #{story.id}, title: '#{escape_javascript(story.title)}', url: '#{story_url(story, :ref => 'tw')}', short_url: '#{story.short_url(@local_site)}'})", :class => opts[:class], :title => "Tweet this story")
    elsif opts[:toolbar]
      short_url = story.short_url(@local_site, ShortUrl::TOOLBAR)
      if short_url.nil? || short_url.length >= 30 # 30 is arbitrary
        ShortUrl.add_or_update_short_url(:page => story, :local_site => @local_site, :url_type => ShortUrl::TOOLBAR, :short_url => short_url || ShortUrl.shorten_url(sharable_story_url(story, :ref => 'tw')))
      end
      link_to opts[:link_text], "http://twitter.com/home?status=#{CGI.escape("Check out '#{story.title}' #{short_url} on #{SocialNewsConfig["app"]["twitter"]}")}", :class => opts[:class], :target => "_blank"
    else
      link_to opts[:link_text], new_sessions_path, :class => opts[:class], :title => "Login to #{SocialNewsConfig["app"]["name"]} to tweet this story"
    end
  end

  def email_page(url_or_story_obj, opts={})
    opts[:type] ||= ""
    opts[:link_text] ||= ""
    opts[:class] ||= "email"
    if opts[:type] == "story"
      return email_story(url_or_story_obj, opts)
    end

    url = url_or_story_obj
    opts[:title] ||= "Email this page to a friend"

    if logged_in?
      # SSS: We are tacking on "ref=email" here .. should this be hardcoded?
      link_to_function(opts[:link_text], "email_page(this, {id: '#{@record_id || request.parameters["id"]}', type: '#{opts[:type]}', url: '#{url}'})", :id => 'email_this_page', :class => opts[:class], :title => opts[:title])
    else
      if opts[:toolbar]
        link_to_function opts[:link_text], "show_popdown_form('log_in')", :id => "nav_login", :class => opts[:class], :title => "Login to #{SocialNewsConfig["app"]["name"]} to " + opts[:title].downcase
      else
        link_to opts[:link_text], new_sessions_path, :class => opts[:class], :title => "Login to " + opts[:title].downcase
      end
    end
  end

  def email_story(story, opts={})
    opts[:link_text] ||= ""
    opts[:class] ||= "email_icon"
    if logged_in?
      # SSS: We are tacking on "ref=email" here .. should this be hardcoded?
	    link_to_function(opts[:link_text], "email_item(this, {id: #{story.id}, title: '#{escape_javascript(StringHelpers::truncate_on_word_boundary(story.title, 0, 50))}', type: 'story', url: '#{story_url(story, :ref => "email")}'})", :class => opts[:class], :title => "Email this story")
	  else
      if opts[:toolbar]
        link_to_function opts[:link_text], "show_popdown_form('log_in')", :id => "nav_login", :class => opts[:class], :title => "Login to #{SocialNewsConfig["app"]["name"]} to email this story"
      else
  	  	link_to opts[:link_text], new_sessions_path, :class => opts[:class], :title => "Login to email this story"
  	  end
	  end
  end

	def addthis_page(url_or_story_obj, opts={})
    opts[:type] ||= ""
    opts[:link_text] ||= ""
    if opts[:type] == "story"
      return share_link(url_or_story_obj, "share", opts[:link_text])
    end

    url = url_or_story_obj
 		"<a href=\"#\" onclick=\"return addthis_open(this, '', #{url.blank? ? 'location.href' : "'#{url}'"}, document.title); return false;\" onmouseout=\"addthis_close()\" target=\"_blank\" class=\"share\" title=\"Add this bookmark and share\">#{opts[:link_text]}</a>"
	end

	# use this to display all the share icons
	# Options you can pass to this routine that will then get passed to the relevant routines:
	# opts[:page_type]
	# opts[:fb_like_layout]
	# opts[:fb_like_show_faces]
	# opts[:fb_like_width]
	# opts[:fb_like_height]
	# opts[:fb_share_layout]
	# opts[:twitter_link_text]
	# opts[:email_link_text]
	# opts[:email_class]
	# opts[:email_title]
	# opts[:addthis_link_text]
	# opts[:toolbar] - set to true if this is displayed on the toolbar
	# in addition, set opts[:fb_like_below] => true if the Like button should be on a second row.
	def share_icons_page(url_or_story_obj, opts={})
    # Resolve a relative path to an absolute url
    url_or_story_obj = LocalSite.home_page(@local_site) + url_or_story_obj if url_or_story_obj.class == String && url_or_story_obj !~ %r{^https?:}

    opts[:class] ||= "share_page_tools"
		display = "<div class=\"#{opts[:class]}\">"
		display += "#{fb_like_iframe(url_or_story_obj, :type => opts[:page_type], :layout => opts[:fb_like_layout], :show_faces => opts[:fb_like_show_faces], :width => opts[:fb_like_width], :height => opts[:fb_like_height])}" unless opts[:fb_like_below]
    #---- No Facebook Share anymore since FB has deprecated that in favour of FB like ---
		#display += fb_share_link(url_or_story_obj, :type => opts[:fb_share_type]) + 
		display += tweet_page(url_or_story_obj, :tweet_text => opts[:tweet_text], :link_text => opts[:twitter_link_text], :type => opts[:page_type], :toolbar => opts[:toolbar]) + 
  		email_page(url_or_story_obj, :link_text => opts[:email_link_text], :class => opts[:email_class], :title => opts[:email_title], :type => opts[:page_type], :toolbar => opts[:toolbar]) +
  		addthis_page(url_or_story_obj, :link_text => opts[:addthis_link_text], :type => opts[:page_type])
  		display += "<div style=\"clear:both; padding-top:14px\">#{fb_like_iframe(url_or_story_obj, :layout => opts[:fb_like_layout], :show_faces => opts[:fb_like_show_faces], :width => opts[:fb_like_width], :height => opts[:fb_like_height])}</div>" if opts[:fb_like_below]
    display += 	"</div>"
	end

	def current_nt_url(path = request.request_uri)
		full_url = LocalSite.home_page(@local_site) + path.strip	  
	end

	def share_icons_box(box_title="Share This")
		"<div class=\"right_column_box span-8 last\">
			<div class=\"top\"></div>
			<div class=\"wrapper\">
				<div class=\"header\">
					<h3 style=\"padding-left:10px;\">#{box_title}</h3>
				</div>
				<div class=\"content clearfix\">
					#{share_icons_page(current_nt_url, :class => "share_page_tools text", :fb_like_below => true, :fb_like_layout => "standard", :fb_like_width => "280", :fb_like_height => "27", :fb_share_type => "icon_link", :twitter_link_text => "Tweet", :email_link_text => "Email", :addthis_link_text => "More")}
				</div>
			<div class=\"bottom\"></div>
		</div>"	  
	end

  def photo_credit(photo)
    if photo.credit_url.blank?
      content_tag('div', "Photo: #{photo.credit.capitalize}", :class => "photo_caption")
    else
      content_tag('div', "Photo: #{link_to(photo.credit.capitalize, photo.credit_url)}", :class => "photo_caption")
    end
  end

  def tooltipped_help_icon(body, opts={})
    opts[:class] ||= "tooltipped_icon"
    tip = ""
    tip += "<div class='tt_head'>#{opts[:head]}</div>" if opts[:head]
    tip += "<div class='tt_subhead'>#{opts[:subhead]}</div>" if opts[:subhead]
    tip += body
    img_tag = image_tag("/images/ui/spacer.gif", :size=>"11x11", :alt => "Help", :class => "#{opts[:class]} help")
    return "#{img_tag}<div class='tooltip'><div class='tooltip_wrapper'>#{tip}</div></div>"
  end

  # little (?) that pops open FAQ
  def help_icon(section="", faq="", title="What does this mean?")
    if (!section.blank? || !faq.blank?)
      return help_link(image_tag("/images/ui/spacer.gif", :size=>"11x11", :alt => "Help"), section, faq,
      :class => "help", :title => "What does this mean?")
    else
      return image_tag("/images/ui/spacer.gif", :size=>"11x11", :alt => "Help", :class => "help", :title => title)
    end
  end
  def help_link(text, section="", faq="", html_options={})
    html_options[:class] ||= ""
    html_options[:class] += " popup_link info_popup"
    return link_to(text, faq_path(:path => faq, :anchor => section), html_options)
  end
  
  def pop_up_link(text, path="", html_options={})
    html_options[:class] ||= ""
    html_options[:class] += " popup_link info_popup"
    return link_to(text, path, html_options)
  end

  def open_popup(content, path="", w=400, h=400)
    width = w + 20
    height = h + 20
    return link_to(content, 
            "#", 
            :onclick => "open_popup('#{path}','', {height:'#{height}', width:'#{width}'}); return false", 
            :html => {"target" => "_blank"})
  end
  
  # conspicuously missing from ActionView::Helpers::UrlHelper.
  #
  def link_to_function_if(condition, *link_to_function_args)
    if condition
      link_to_function *link_to_function_args
    else
      content_tag :span, link_to_function_args.first
    end
  end

  def close_this_panel(opts={})
    opts[:title] ||= "Minimize this panel"
    opts[:text] ||= "Close this panel"
    opts[:class] ||= "close_button"
    link_to_function opts[:text], "show_popdown_form()", :class => opts[:class], :title => opts[:title] if !params[:popup] 
  end

  def popup_check(opts={})
    # SSS:
    # 1. This could be slow -- because of the rescue-catch for every link being rendered.
    # 2. is_popup = ((defined?(params) || params.nil?) ? params : {})[:popup]
    #               fails for some unknown reason. 
    #               Ruby complains of params being undefined even though I've already checked for that!
    #               This breaks down only for params, works for other methods and variables.  Weird!
    #    Hence the rescue song-and-dance
    # 3. params ||= {} also fails when there is an existing method definition -- it always sets params to {}
    #    bad spec / undefined spec / ruby implementation bug?
    begin
      is_popup = params[:popup]
    rescue
      is_popup = false
    end
    is_popup ? (opts[:add_class] ? 'class="outbound"' : " outbound") : ""
  end

  # Overwrite the rails h method so that we can use our own more robust sanitization method
  def h(str)
    sanitize_html(str)
  end

  # strip the tags
  def s(str)
    # SSS: Dont use this homebrewed code -- it goes into a tailspin on certain strings like the example below!
    #     <p><a href=ddsaustin.com\">dental austin</a></p>
    #
    # str.gsub(%r{<(?:[^>"']+|"(?:\\.|[^\\"]+)*"|'(?:\\.|[^\\']+)*')*>}xm,'')
    #
    # Use the Rails builtin strip_tags sanitizer
    strip_tags(str)
  end

  # if a review isn't public, display the red 'hidden' message
  # note that we don't want to display the review's actual status since it could
  # be list or feature, and still be hidden due to the member's status
  def review_hidden(review, message = "Hidden")
    unless review.is_public?
      return '<span class="quiet small">(' + message + ')</span>'
    end
  end

  # SSS: Should never ever have to use 'm'
  def can_follow?(m = nil)
    #logged_in? and ((current_member.has_role_or_above?(:staff) || current_member.in_group?(:betatest))
    logged_in? && @local_site.nil?  # No follows for guests or on local sites (yet)
  end

  # SSS: NOTE: This is fragile -- assumes that the timezone of the server is set to PT.
	def pt_et_convert(hour=0,minutes=0)
		pt = Time.parse("#{hour}:#{minutes}")
		et = Time.parse("#{hour + 3}:#{minutes}")
		return "#{et.strftime("%I%p").gsub(/^0/, '').downcase} ET (#{pt.strftime("%I%p").gsub(/^0/, '').downcase} PT)"	  
	end

  def newsletter_time(freq)
    pt_et_convert(Newsletter::DELIVERY_TIMES[freq]["hour"], Newsletter::DELIVERY_TIMES[freq]["min"])     
  end

  # More >>
  def more_link(more_url, html_options={})
    html_options[:class] ||= "more_url"
    link_to("More&nbsp;&raquo;", more_url, html_options) unless more_url.blank?
  end

  # display both the story_type and online_access info, separated by a hyphen
  def story_type_and_online_access(story)
    story_type = story.story_type.blank? ? nil : humanize_token(story, :story_type)
    online_access = (!story.online_access.blank? and story.online_access != "full_access") ? humanize_token(story, :online_access) : nil
    story_type_and_online_access = [story_type.blank? ? nil : story_type, online_access.blank? ? nil : online_access].compact.join(" - ")
    return "(#{story_type_and_online_access})" unless story_type_and_online_access.blank?
  end


	def guides_toc(page, key, title, link)
		page == key ? '<li class="grayed_out"><strong>' + title + '</strong></li>' : '<li>' + link_to(title, '/guides/' + link) + '</li>'
	end  


  # Display a specific number of items in a comma-separated list with "..."
  # at the end if the list continues
  def display_partial_list(list, max)
    return_val = ""
    sep = ", "
    list_array = list.split(',',max+1)
    0.upto(max-1) do |i|
      if list_array[i]
        if !list_array[i+1]
          sep = ""
        end
        return_val += list_array[i] + sep
        if i == max-2
          sep = "..."
        end
      end
    end
    return return_val
  end


  # Format a number nnnnnnn.dd to n,nnn,nnn.dd
  # will work with integers or floats, or numbers already converted to strings
  def number_format(num)
    
    return num.to_s.gsub(/(\d)(?=\d{3}+(\.\d*)?$)/, '\1,')
    
  end


  # Display a number along with the proper plural form of the noun that follows
  # also adds commas at the thousands place.
  def plural(num,str)

    num_str = number_format(num)
    if num == 1
      return num_str + ' ' + str
    else
      return num_str + ' ' + str.pluralize
    end 
   
  end
  
  # Display a word with the proper "a" or "an" article before it
  def a_or_an(word)
    word = word.strip
    if %w{a e i o u}.include? word[0..0].to_s.downcase
      "an #{word}"
    else
      "a #{word}"
    end    
  end
  
  # Convert from textile format to html_options
  def detextilize(str)
      RedCloth.new(str).to_html
  end
  
  # What browser are they using?
  def client_browser_name 
    user_agent = (request.env['HTTP_USER_AGENT'] || "").downcase 
    if user_agent =~ /msie/i 
      "Internet Explorer" 
    elsif user_agent =~ /applewebkit/i 
      "Safari" 
    elsif user_agent =~ /konqueror/i 
      "Konqueror" 
    elsif user_agent =~ /gecko/i 
      "Mozilla" 
    elsif user_agent =~ /opera/i 
      "Opera" 
    else 
      "Unknown" 
    end 
  end 

  # What browser are they using?
  def client_browser_version 
    user_agent = (request.env['HTTP_USER_AGENT'] || "").downcase 
    if user_agent =~ /msie 8/i 
      "MSIE8" 
    elsif user_agent =~ /msie 7/i 
      "MSIE7" 
    elsif user_agent =~ /msie 6/i 
      "MSIE6" 
    else 
      "Other" 
    end 
  end 

  def follow_item_js_opts(follow_type, item, follower = nil, refresh_panel = true)
    follow_item_opts(follow_type, item, follower, refresh_panel).to_json.gsub('"', "'")
  end

  def follow_item_opts(follow_type, item, follower = nil, refresh_panel = true)
    opts = { :type => follow_type, :id => item.id, :refresh_panel => refresh_panel }
    if refresh_panel
      opts.merge!({:name => item.name, :icon => item.favicon })
      case follow_type.downcase
        when 'feed'   then opts[:url] = feed_path(item)
        when 'source' then opts[:url] = source_path(item)
        when 'topic'  then opts[:url] = item.class == Topic ? topic_path(item) : subject_path(item)
        when 'member'
          opts[:fb_flag] = fbc_session_user_friends_with?(item)
          opts[:twitter_flag] = is_twitter_follower?(follower, item)
          opts[:mutual_follow_flag] = follower.mutual_follower?(item)
          opts[:url] = member_path(item)
      end
    end
    opts
  end

  def follow_item_generic(follower, type, item, opts={})
    opts[:follow_only] ||= false		# currently not being used anywhere
    opts[:refresh_panel] ||= false
    opts[:style] ||= ""
    style = opts[:style].blank? ? "" : 'style="{opts[:style]}" '
    if can_follow?
      if type == "member" && item != follower
        followed = follower.followed_members.include?(item)
      elsif type == "source"
        followed = follower.followed_sources.include?(item)
      elsif type == "topic"
        followed = follower.followed_topics.include?(item)
      elsif type == "feed"
        followed = follower.followed_feeds.include?(item)
      else
        return
      end
      if followed
        fc = "unfollow_button"
        title = "Unfollow #{item.name}"
      else
        if opts[:follow_only]
          fc = "follow_only_button"
        else
          fc = "follow_button"
        end
        title = "Follow #{item.name}"
      end
      if !opts[:follow_only] || !followed 
        ## IMPORTANT: Use double quotes below!  The js code from follow_item_js_opts uses single-quotes.
        "<a href=\"#\" class=#{fc} #{style}onclick=\"return toggle_follow(this, #{follow_item_js_opts(type, item, follower, opts[:refresh_panel])})\" title=\"#{title}\"></a>"
      end
    end      
  end

  def follow_item(type, item, opts={})
    follow_item_generic(current_member, type, item, opts)
  end

  def follow_button(member)
    if can_follow? && member != current_member
      item_opts = { :type => 'member', :id => member.id, :refresh_panel => false }
      if current_member.followed_members.include?(member)
        ## IMPORTANT: Use single quotes below!  The js code from to_json uses double-quotes.
        return "<a href=\"#\" class=\"unfollow_btn\" onclick='return toggle_follow(this, #{item_opts.to_json})' title=\"Unfollow #{first_name(member)}\"></a>"
      else
        ## IMPORTANT: Use double quotes below!  The js code from to_json uses double-quotes.
        return "<a href=\"#\" class=\"follow_btn\" onclick='return toggle_follow(this, #{item_opts.to_json})' title=\"Follow #{first_name(member)}\"></a>"
      end
    end
  end

  # Lists all groups a member belongs to, in order by group_list.
  def list_member_groups(member, options = {})
    list = ""
    sep = ""
    if options[:group_list]
      group_list = options[:group_list]      
      cnt = group_list.length
  
      if member.total_reviews > 0 && member.status == 'member'
        if !member.awards.blank? && member.awards.split(",").map(&:strip).find { |a| a =~ /certified_student_reviewer/}
          list = options[:badges] ? '<span class="certified_reviewer"></span>' : "Certified Student Reviewer"
        else
          list = options[:badges] ? '<span class="reviewer_badge"></span>' : "Reviewer"
        end
        sep = ", "
      end
      if member.is_trusted_member?
        list += options[:badges] ? '<span class="trusted_member_badge"></span>' : sep + "Trusted Member"
        sep = ", "
      end
      if member.is_student?
        list += options[:badges] ? '<span class="student_badge"></span>' : sep + "Student"
        sep = ", "
      end
      if member.is_educator?
        list += options[:badges] ? '<span class="educator_badge"></span>' : sep + "Educator"
        sep = ", "
      end
      0.upto(cnt-1) do |i|
        if member.in_group?(group_list[i])
          if options[:badges]
            list += '<span class="' + humanize_token_direct("member_groups", group_list[i]).downcase + '_badge"></span>'          
          else
            list += sep + humanize_token_direct("member_groups", group_list[i])
            sep = ", "
          end
        end
      end
    end
    if list == ""
      list = "No Roles"
    end
    return list
    
  end
  
  def admin_only_content(current_member = nil, &block)
    yield if current_member && current_member.has_role_or_above?(:admin)
  end

  def display_member_status(member)
    if member.status == "member" && member.in_group?("founding")
      return humanize_token_direct("member_groups", "founding")
    else
      return humanize_token(member, :status)
    end
    
  end
  
  # display a list of serch sites
  def research_sites(search_str)
    search_sites = link_to "Google", 'http://www.google.com/search?q=' + search_str, :target => '_blank'
    search_sites += ' | '
    search_sites += link_to "Yahoo", 'http://search.yahoo.com/search?p=' + search_str, :target => '_blank'
    search_sites += ' | '
    search_sites += link_to "Technorati", 'http://www.technorati.com/search' + search_str, :target => '_blank'
    search_sites += ' | '
    search_sites += link_to "Wikipedia", 'http://en.wikipedia.org/w/wiki.phtml?search=' + search_str, :target => '_blank'
    search_sites += ' | '
    search_sites += link_to "del.icio.us", 'http://del.icio.us/search/?all=' + search_str, :target => '_blank'
  end

  # Convenience wrapper for StringHelpers tool
  #
  def truncate_on_word_boundary(string, options = {})
    StringHelpers.truncate_on_word_boundary(string, options[:min_chars] || 0, options[:max_chars] || 140) || ""
  end
  
  def truncate(string, min, max, options = {})
    StringHelpers.truncate(string, min || 5, max || 140, false) || ""
  end

  # use time_ago_in_words if it's less than a week ago
  
  def story_time_ago(story_date)
    distance_in_days = (((Time.now - story_date).abs)/1.days).to_i
    distance_in_days > 7 ? story_date.strftime('%b. %e, %Y') : distance_in_days < 1  ? "Today" : "#{time_ago_in_words(story_date) } ago"
  end

  def nt_colors
    return "<strong><span style='color:#385ac8'>News</span><span style='color:#399800'>Trust</span></strong>"  
  end

  
  # LAYOUT HELPERS
  #  
  # display one line of a member/source/etc profile/overview
  def profile_line(record, attribute_keys, options = {})
    values = []
    separator = options[:separator] || ", "
    # turn attribute_keys into array in case there are multiple attributes
    attribute_keys = [attribute_keys] if attribute_keys.class != Array
    attribute_keys.each do |key|
      # get attribute from monkeypatched FlexAttributes (will be nil if visible == false)
      value = record.visible_attribute(key)
      if value
        # use :formatter if there is one
        value = humanize_token(record, key) if options[:humanize_token]
        value = send(options[:formatter].to_s, value, key) if options[:formatter]
        unless value.blank?
          values << value
        end
      # if empty value but if_empty_say option is present, display its contents instead
      elsif options[:if_empty_say]
        values << options[:if_empty_say]
      end
    end
    # display
    if !values.compact.empty?
      profile_line_direct(
        :humanized_key => options[:humanized_key] || attribute_keys.first.titleize,
        :value => values.join( separator ))
    end
  end

  def aggregate_info_profile_line(record, stat, options={})
    stat_array = AggregateStatistic.find_statistic(@source, stat, @local_site ? @local_site.id : nil)
    if !stat_array.empty?
       model         = options[:model]
       link_it       = options[:link_it] || false
       formatter     = options[:formatter]
       humanized_key = options[:humanized_key] || stat.split("_").map(&:capitalize).join(" ")
       stat_array.each { |s| m = model.find(s[0]); s[0] = link_to(m.name, m) } if link_it && model
       profile_line_direct(:humanized_key => humanized_key, :value => send(formatter, stat_array, stat))
    end
  end
  
  # can now pass in faq#section info
  def profile_line_direct(options)
    options[:faq] ||= nil
    options[:section] ||= nil
    render(:partial => 'shared/profile_line', :locals => options) unless options[:value].blank?
  end
  
  def profile_section(section_header, options = {}, &block)
    options[:section_header] = section_header
    options[:help_icon] ||= ""
    options[:extra_class] ||= ""
    render_partial_with_block 'shared/profile_section', options, &block
  end
    
  def right_column_box(options = {}, &block)
    options[:header] ||= nil
    options[:tabs] ||= []
    options[:id] ||= "right_column_box"
    options[:disclaimer] = options[:disclaimer_link] ?
      content_tag(:span, "(#{options[:disclaimer_link]})", :class => "disclaimer editorial_gray") :
      ""
    options[:deactivated_links] ||= []
    render_partial_with_block 'shared/right_column_box', options, &block
  end
  
  def disclosable(options={}, &block)
    options[:link_text] ||= ""
    options[:show_link_text] ||= "show #{options[:link_text]} &raquo;"
    options[:hide_link_text] ||= "hide #{options[:link_text]}"
    options[:show] ||= false
    options[:callback] = options[:callback].nil? ? "" : ", #{options[:callback]}"
    render_partial_with_block 'shared/disclosable', options, &block
  end
  
  def more_info_box(options={}, &block)
    render_partial_with_block 'shared/more_info_box', options, &block
  end
  
  def main_column_tabless_box(options = {}, &block)
    options[:tabs] = []
    main_column_box(options, &block)
  end
  def main_column_box(options = {}, &block)
    options[:box_id] ||= "main_column_tabbed_box"
    options[:box_class] ||= "main_column_box"
    options[:header] ||= ""
    options[:callback] ||= nil
    options[:tab_classes] ||= nil
#    options[:tabs_leader_text] ||= ""
    render_partial_with_block 'shared/main_column_box', options, &block
  end
  alias_method :main_column_tabbed_box, :main_column_box
  alias_method :tabbed_box, :main_column_box
  
  def main_column_tab(options = {}, &block)
    options[:first_tab] ||= false
    options[:anchor_class] ||= ""
    render_partial_with_block 'shared/main_column_tab', options, &block
  end
  alias_method :tabbed_box_tab, :main_column_tab
  
  # see http://errtheblog.com/posts/11-block-to-partial
  def render_partial_with_block(partial_name, options = {}, &block)
    block_output = capture(&block)
    unless !options[:force_display] && block_output.strip.blank?
      # options.merge!('@content_for_layout' => block_output) # doesn't work as of Rails 2.1
      # response.template.instance_variable_set("@content_for_layout", capture(&block)) # supposed to fix, but also doesn't work
      options.merge!(:content => block_output) # so just use 'content' instead of 'yield' in layouts!
      concat(render(:partial => partial_name, :locals => options))
    end
  end

  def comment_permalink_for(comment)
    url = ''
    if comment.commentable
      comment_type = comment.commentable.class == 'Topic' ? comment.commentable.type.to_s : comment.commentable.class.to_s
      url = case comment_type
      when "Source"
        source_url(comment.commentable)
      when "Topic"
        topic_url(comment.commentable)
      when "Subject"
        subject_url(comment.commentable.slug)
      when "Story"
        story_url(comment.commentable)
      when "Review"
        review_url(comment.commentable.story, comment.commentable)
      when "Quote"
        quote_url(comment.commentable)
      when "Group"
        group_url(comment.commentable)
      else
        ""
      end
    end
    url + "#p-#{comment.id}"
  end

  def comment_url_for(comment)
    url = ''
    if comment.commentable
      comment_type = comment.commentable.class == 'Topic' ? comment.commentable.type.to_s : comment.commentable.class.to_s
      url = case comment_type
      when "Source"
        source_url(comment.commentable)
      when "Topic"
        topic_url(comment.commentable)
      when "Subject"
        subject_url(comment.commentable.slug)
      when "Story"
        story_url(comment.commentable)
      when "Review"
        review_url(comment.commentable.story, comment.commentable)
      when "Quote"
        quote_url(comment.commentable)
      when "Group"
        group_url(comment.commentable)
      else
        ""
      end
    end
    url
  end

  def comment_title_for(comment)
    if comment.commentable
      comment_type = comment.commentable.class == 'Topic' ? comment.commentable.type.to_s : comment.commentable.class.to_s
      case comment_type
      when "Source", "Topic", "Subject", "Group"
        comment.commentable.name
      when "Story"
        comment.commentable.title
      when "Review"
        comment.commentable.story.title
      when "Quote"
        comment.commentable.quote
      else
        ""
      end
    end
  end

  def tools_box(options = {}, &block)
    options[:force_display] = true
    render_partial_with_block 'shared/tools_box', options, &block
  end
  
  # Make it easier to grab a token from the config files
  # Must pass record and the key, to be used from an .erb file or profile_line
  # Usage:  to convert the @story.story_type string (accessing story_format in the yml file)
  #         <%= humanize_token(@story, :format) %>
  # or, to ask profile_line to convert, add this to the options:
  #         :humanize_token => true
  def humanize_token(record, key)
    humanize_token_direct("#{record.class.name.underscore}_#{key}", record.send(key))
  end
  
  # Direct Make it easier to grab a token from the configconfig files
  # Usage:  to convert the @story.story_type string (accessing story_format in the yml file)
  #         <%= humanize_token_direct("source_media", @source.primary_medium, select) %>
  def humanize_token_direct(token, value, select="name")
    token_info = SiteConstants::ordered_hash(token)[value]
    return token_info[select] if token_info && value
  end
  
  # used to display a pull-down menu from the config files
  # adds separators where applicable
  # Usage: pass the name of the section in the yml file
  def pull_down_menu(category, config_selector=nil)
    menu_options = []
    root_hash = config_selector.nil? ? SocialNewsConfig : SocialNewsConfig[config_selector]
    root_hash[category].each_with_index do |so, i|
      if (so.values.first["group"] and (so.values.first["group"] != root_hash[category][i-1].values.first["group"]))
        menu_options << ["--- #{so.values.first['group'].humanize} ---", ""]
      end
      menu_options << [so.values.first["name"], so.keys.first]
    end
    return menu_options
  end
  

  # used to display all items in one of the constants file
  # Usage: pass the name of the section in the yml file
  def display_constants_list(category)
    menu_options = []
    SocialNewsConfig[category].each_with_index do |so, i|
      if (so.values.first["group"] and (so.values.first["group"] != SocialNewsConfig[category][i-1].values.first["group"]))
        menu_options << ["<br><h3>#{so.values.first['group'].humanize}</h3>"]
      end
      menu_options << ["#{so.values.first["name"]}<br>"]
    end
    return menu_options
  end


  # Convert Last, First to First Last
  def flip_first_last_name(name)
    fixed_name = name.split(", ")
    if fixed_name[1] 
      fixed_name[1] + ' ' + fixed_name[0]
    else
      name
    end
  end

  # Other format helpers
  def format_email(email_address, key)
    mail_to(email_address, email_address, :encode => "javascript")
  end
  
  def format_date(date, key)
    if !date
      Never
    else
      date.strftime('%b %e, %Y - %l:%M %p %Z')
    end
  end

  def format_date_only(date, key)
    if !date
      Never
    else
      date.strftime('%b %e, %Y')
    end
  end

  def date_as_words(date_time = nil)
    format = '%A, %B %d, %Y'
    date_time.strftime(format) unless date_time.nil?
  end

  # used to display the address info
  # Format: don't display any field that is set to "n/a"
  def format_filter_na(loc, key)

    # if it's "n/a" then don't display here
    if loc == "n/a"
      return ""
    end
    return loc
  end

  # Check if tab specifies the partial to use and a set of locals
  # If not, look if there is a partial with the tab listing type name 
  # If not, use the default listing partial
  def render_landing_page_listing(tab, page_obj, default_locals = nil)
    if !tab[:partial].blank?
      partial = tab[:partial]
      locals  = tab[:locals]
    else
      partials_dir = "shared/landing_pages/listings"
      partial = "#{partials_dir}/#{File.exists?("#{RAILS_ROOT}/app/views/#{partials_dir}/_#{tab[:type]}.html.erb") ? tab[:type] : 'default'}"
      locals  = default_locals.merge(:listing_type => tab[:type])
    end
    render :partial => "#{partial}", :locals => locals.merge(:page_obj => page_obj)
  end

  def nt_colors
    return "<span class='nt_blue'>N</span><span class='nt_green'>T</span>"  
  end

  def validation_email_url
    profile_url = "http://#{APP_DEFAULT_URL_OPTIONS[:host]}/members/#{current_member.friendly_id}"
    "<a href='mailto:#{SocialNewsConfig["email_addrs"]["community"]}?subject=Validation request from #{current_member.name}&body=Hello #{SocialNewsConfig["app"]["name"]},&body=&body=Please validate my account, so I can post stories and comments on #{SocialNewsConfig["app"]["name"]}.&body=&body=Here is my member profile url: #{profile_url}&body=&body=Thank you,&body=#{current_member.name}'>email us</a>"
  end

  def process_template(template)
    # Handle both erb & textile in one shot
    # IMPORTANT: Pass in the current binding so it has access to url & tag helpers
    RedCloth.new(ERB.new(template).result(binding)).to_html
  end

  # SSS:
  # In Rails 2.1, do not move this back to the invitation model
  # That would require having to include actionview helpers into the model 
  # which introduces weird bugs elsewhere in the codebase because of method name
  # conflicts (ex: tag method is defined by app/models/topic.rb as well as the
  # actionview helpers).
  def attr_with_erb_to_html(invitation, attribute)
    process_template(invitation.send(attribute.to_sym,:source))
  rescue Exception => e
    "#{e.class} in ERB for #{attribute.to_s}: #{e.message}"
    logger.error "#{e.class} in ERB for #{attribute.to_s}: #{e.message}: BT: #{e.backtrace.inspect}"
  end

#  # SSS: Copied from actionview helpers
#
#  def js_antispam_email_link(email_address, name, email_opts={})
#    cc, bcc, subject, body = email_opts.delete("cc"), email_opts.delete("bcc"), email_opts.delete("subject"), email_opts.delete("body")
#
#    email_href = "mailto:#{email_address}"
#    email_href << "cc=#{CGI.escape(cc).gsub("+", "%20")}&" unless cc.nil?
#    email_href << "bcc=#{CGI.escape(bcc).gsub("+", "%20")}&" unless bcc.nil?
#    email_href << "body=#{CGI.escape(body).gsub("+", "%20")}&" unless body.nil?
#    email_href << "subject=#{CGI.escape(subject).gsub("+", "%20")}&" unless subject.nil?
#    email_href = "?" << email_href.gsub!(/&?$/,"") unless email_href.empty?
#
#    str = ''
#    "document.write('<a href=\"#{email_href}\">#{name}</a>');".each_byte { |c| str << sprintf("%%%x", c) }
#    "<script type=\"text/javascript\">eval(unescape('#{str}'))</script>"
#  end

  def process_template_macros(content, body=nil)
    content.gsub!('&lt;={page}=&gt;', body || "")
    content.gsub!(/&lt;=\{fb_login_button\((.*?),\s*(.*?)\)\}=&gt;/, "<fb:login-button onlogin=\"fbc_activate('\\1', '')\" length=\"\\2\" v=\"2\"></fb:login-button>")
    content.gsub!(/&lt;=\{share_icons_box\}=&gt;/) { |m| share_icons_box }
    content
  end

  def wrap_page_template(template, &block)
    # As a 1-liner this would be, but a little hard to read
    #
    # concat(process_template_macros(process_template(template), capture(&block)), block.binding)

    body = capture(&block)
    content = process_template(template)
    content = process_template_macros(content, body)
    concat(content)
  end
end
