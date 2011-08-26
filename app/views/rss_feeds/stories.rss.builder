aname = app_name
@url_tracking_key ||= "rss"
xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "#{aname} - #{@feed_data[:feed_title]}"
    xml.copyright "Copyright (c) 2008 #{aname}"
    xml.language "en-us"
    xml.lastBuildDate Time.now.to_s(:rfc822)
    xml.image do
      xml.url home_url + SocialNewsConfig["app"]["mini_logo_path"]
      xml.title aname
      xml.link @feed_data[:listing_url]
    end
    xml.link @feed_data[:listing_url]
    xml.description "#{aname} features top-rated stories from hundreds of mainstream and independent sources. Find out more at #{home_url}"

      ## Common story footer
    story_footer_txt = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; #{link_to "Visit #{aname}", home_url, :only_path => false} | #{link_to 'About', home_url + 'about', :only_path => false} | #{link_to 'Sign Up', home_url + 'partners/feeds/rss'} | #{link_to 'Disclaimer', home_url + 'about/disclaimer', :only_path => false}"

    @feed_data[:items].each do |story|
        ## Build the various pieces of the rss item
      s_url          = @url_tracking_key ? story_url(story, :ref => @url_tracking_key) : story_url(story)
      review_url     = story.from_framebuster_site? ? s_url : (@url_tracking_key ? toolbar_story_url(story, :ref => @url_tracking_key) : toolbar_story_url(story))
      source         = story.primary_source
      source_link    = (!source) ? "" : (source.is_public? ? link_to(source.name, source_url(source, :ref => @url_tracking_key)) : source.name)
      journos        = ' - By ' + story.journalist_names if !story.journalist_names.blank?
      story_date     = (story.story_date || Time.now).strftime("%b. %d")
      story_type     = ' (' + (humanize_token(story, :story_type) || "") + ')' if story.story_type
      num_reviews    = story.reviews_count
      min_reviews    = SocialNewsConfig["min_reviews_for_story_rating"]
      ## SSS: because of background processing of reviews & stories, a story may not yet have a rating even though it has reviews!
      rating_link    = link_to((num_reviews == 0) ? "Not rated yet" : sprintf('%0.1f', story.rating || 1.0) + ' average', s_url, :only_path => false)
      reviews_link   = " - #{rating_link.sub(/>.*?</, ">" + see_reviews_link_text(story) + "<")}"
      rating_link    = "<b>#{aname} Rating: </b>#{rating_link}#{' (not enough reviews)' if (num_reviews > 0) && (num_reviews < min_reviews)}"
      review_it_link = link_to "Review It", review_url

        ## Spit it out
      xml.item do
        xml.title       story.title
        xml.pubDate     story.story_date.to_s(:rfc822)
        xml.guid        review_url, :isPermaLink => true
        xml.link        review_url
        xml.description "<span>#{source_link}#{journos} - #{story_date}#{story_type} - #{story.excerpt}</span><p>#{rating_link}#{reviews_link} - #{review_it_link}#{story_footer_txt}</p>"
        ts = story.topics(@local_site)
        ts.each { |t| xml.category t.name } if !ts.blank?
      end
    end
  end
end
