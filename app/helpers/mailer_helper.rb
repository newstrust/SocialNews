module MailerHelper

  # Google Analytics link source-tracking params. Only "utm_campaign" is optional, but seems valuable.
  # Add in our own url refs too!
  def newsletter_link_params(newsletter_frequency)
    {:ref => Newsletter.url_tracking_key(newsletter_frequency), :utm_source => "#{Time.now.strftime('%Y%m%d')}_listing", :utm_campaign => "#{newsletter_frequency}_newsletter", :utm_medium => "email"}
  end

  def newsletter_toolbar_link(story, link_params, opts={})
    if story.from_framebuster_site? || story.is_pdf?
      # route-generation method is very sensitive to that second arg .. so, slice off :go from options
      story_url(story, link_params)
    else
      # route-generation method is very sensitive to that second arg .. so, slice off :go from options
      opts.merge!(link_params)
      toolbar_story_url(story, opts)
    end
  end
end
