module MynewsHelper
  include MembersHelper

  def filter_options_box(options={}, &block)
    render_partial_with_block 'mynews/filter_options_box', options, &block
  end

  def mynews_colors
    return "<strong><span class='nt_green'>My</span><span class='nt_blue'>News</span></strong>"  
  end

  def in_beta(member)
    (member.has_role_or_above?(:staff) || member.in_group?(:betatest))
  end

  def select_mynews_badge(member)
    if member.followed_items.count < 3
      badge_codes  = ["setup"]
    else
      badge_codes  = [ "donate", "mynews", "widget", "invite"]
      badge_codes += ["fb_friends"]      if facebook_session.nil? || !(member.fbc_followable_friends(facebook_session) - member.followed_members).empty?
      badge_codes += ["twitter_friends"] if !(member.twitter_followable_friends - member.followed_members).empty?
      badge_codes += ["fb_feed"]         if !member.follows_fb_newsfeed?
      badge_codes += ["twitter_feed"]    if !member.follows_twitter_newsfeed?
#      badge_codes += ["fb_invite"]       if member.fbc_linked?

        # pick "email" 50% of the time if they're not subscribed
      (1..badge_codes.length).each { badge_codes << "email" } if !member.has_newsletter_subscription?(Newsletter::MYNEWS)
    end

    # Pick a random badge!
    case badge_codes[rand(badge_codes.length)]
      when "donate" then link_to(image_tag("/images/ntbadges/mynews_donate.png"), "/donate")
      #when "survey" then link_to(image_tag("/images/ntbadges/mynews_survey.png"), "http://www.surveymk.com/s/mynews", :target => "_blank")
      when "mynews" then help_link(image_tag("/images/ntbadges/mynews_help.png"), "about_mynews","mynews")
      when "widget" then link_to(image_tag("/images/ntbadges/mynews_widget.png"), "/widgets?url=/members/#{@member.friendly_id}/mynews")
      when "invite" then link_to(image_tag("/images/ntbadges/mynews_tellafriend.png"), "/members/invite")
      when "email"  then link_to(image_tag("/images/ntbadges/mynews_email.png"), manage_subscription_path(:freq => Newsletter::MYNEWS), :alt => "Manage your MyNews email subscription", :title => "Manage your MyNews email subscription")
      when "setup"  then link_to(image_tag("/images/ntbadges/mynews_setup.png"), "#", :alt => "Click to change your MyNews settings", :title => "Click to change your MyNews settings", :onclick=> 'toggle_filter_panel();return false;')
      when "fb_invite" then link_to(image_tag("/images/ntbadges/mynews_facebook_invite.png"), "#", :alt => "Invite your Facebook friends to try MyNews", :title => "Invite your Facebook friends to try MyNews", :onclick => "open_popup('#{fb_invite_friends_path}', '', {height:600, width:800})")
      when "fb_friends" then link_to(image_tag("/images/ntbadges/mynews_facebook_friends.png"), "#fb_friends_panel", :alt => "Find friends from Facebook", :title => "Find friends from Facebook", :onclick=> 'toggle_fb_friends_panel()')
      when "fb_feed" then link_to(image_tag("/images/ntbadges/mynews_facebook_feed.png"), "#fb_feed_panel", :alt => "Follow news from your Facebook feed", :title => "Follow news from your Facebook feed", :onclick=> 'toggle_fb_feed_panel()')
      when "twitter_friends" then link_to(image_tag("/images/ntbadges/mynews_twitter_friends.png"), "#twitter_friends_panel", :alt => "Find friends from Twitter", :title => "Find friends from Twitter", :onclick=> 'toggle_twitter_friends_panel()')
      when "twitter_feed" then link_to(image_tag("/images/ntbadges/mynews_twitter_feed.png"), "#twitter_feed_panel", :alt => "Follow news from your Twitter feed", :title => "Follow news from your Twitter feed", :onclick=> 'toggle_twitter_feed_panel()')
    end
  rescue Exception => e
    RAILS_DEFAULT_LOGGER.error "Exception '#{e}' getting mynews badge for #{member.id}"
    link_to(image_tag("/images/ntbadges/mynews_donate.png"), "/donate")
  end
  
  def true_color(b)
    unless b.nil?
      return "<span style=\"color:#{b ? "green" : "gray"}\">#{b}</span>"
    end
  end

end

