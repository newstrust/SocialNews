class FbConnectPublisher
  MAX_QUOTE_LENGTH = SocialNewsConfig["fbc"]["max_quote_length"]
  MAX_COMMENT_LENGTH = SocialNewsConfig["fbc"]["max_comment_length"]
  APP_NAME = SocialNewsConfig["app"]["name"]

  include ReviewsHelper
  @@helper_dummy = FbConnectPublisher.new

  def publish_stream(params, fb_session_user = nil, target_user = nil)
    send_as :publish_stream
    attachment params[:attachment]
    message params[:message]
    action_links params[:action_links]
    from fb_session_user if fb_session_user
    target target_user if target_user
  end

  def self.stream_story_for_review(review, full_urls)
    story = review.story
    note  = review.comment 
    story_url = full_urls[:story_url]
    toolbar_url = full_urls[:toolbar_url]

    # Prevent jumbling up of order of these properties!
    props = ActiveSupport::OrderedHash.new
    props["#{review.member.first_name}'s Rating"] = { :text => "#{@@helper_dummy.format_rating(review.rating)} | Reviews &raquo;", :href => story_url }
#    props["Add your 2 cents"] = { :text => "Review this story", :href => story.from_framebuster_site? ? story_url : toolbar_url + "?go=review" }
    props["News Source"] = { :text => story.primary_source.name, :href => story.from_framebuster_site? ? story.url : toolbar_url }
    comment = StringHelpers.truncate_on_word_boundary(review.personal_comment, 0, MAX_COMMENT_LENGTH, false) if review.personal_comment

    # create stream item
    {
      :name         => story.title,
      :link         => story.from_framebuster_site? ? story.url : toolbar_url,
      :caption      => "{*actor*} reviewed this story on #{APP_NAME}",
      :description  => note.blank? ? "" : "\"#{StringHelpers.truncate_on_word_boundary(note,0,MAX_QUOTE_LENGTH,false)}\"<br/>",
      :properties   => props,
      :message      => comment,
      :actions      => [{ :name => "Visit #{APP_NAME}", :link => full_urls[:home_url] }],
      :comments_xid => review.id
    }
  end
end
