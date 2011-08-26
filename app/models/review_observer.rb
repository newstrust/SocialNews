class ReviewObserver < ActiveRecord::Observer
  def after_create(review)
    story_id = review.story.id
    review.member.social_groups.each { |g| g.add_story(story_id) } if review.member
  end
  
  # custom observer hook, so we can be sure that story has been processed before this code is executed.
  # Cf. http://alexkira.blogspot.com/2008/10/custom-observer-callbacks-in-rails.html
  #
  # This is triggered via 'notify' in acts_as_processable.
  #
  def after_processing_propagation(review)
    sent_to_members = []

    # - no need to let people know if they can't get to the profile of the reviewer
    # - only trigger notifications if this is a create and not an update
    # - dont bother sending more review notifications if the story has more than 20 reviews 
    if review.member.is_visible? && review.was_new_record? && (review.story.reviews_count < 20)
    
      # when someone reviews a story you submitted (as long as it's not you!)
      story_submitter = review.story.submitted_by_member
      if story_submitter.email_notification_preferences.submitted_story_reviewed && story_submitter != review.member
        reviewer = review.member || Member.nt_anonymous # Handle situation of a guest reviewer!
        PendingNotification.create(:local_site_id => review.local_site ? review.local_site.id : nil, :member_id => story_submitter.id, :notification_type => PendingNotification::NEW_REVIEW, :trigger_obj_type => review.class.name, :trigger_obj_id => review.id)
        sent_to_members << story_submitter
      end
      
      # only send notifications to other reviewers/likers if the new review has a comment, quote, or related link,
      # or this is the review that gives us enough to cause the story to be rated (now 3)
      story_relations_by_member = review.story.story_relations.reject { |r| r.related_story.nil? || r.member_id != review.member.id  || r.related_story.status == 'hide' }
      if (!review.comment.blank? || !review.personal_comment.blank? || !review.excerpts.empty? || \
          !story_relations_by_member.empty? || review.story.reviews_count == SocialNewsConfig["min_reviews_for_story_rating"])

        # when someone reviews a story you have also reviewed
        (review.story.reviews.map(&:member) - [review.member]).each do |fellow_reviewer|
          if fellow_reviewer && fellow_reviewer.email_notification_preferences.reviewed_story_reviewed && !sent_to_members.include?(fellow_reviewer)
            reviewer = review.member || Member.nt_anonymous # Handle situation of a guest reviewer!
            PendingNotification.create(:local_site_id => review.local_site ? review.local_site.id : nil, :member_id => fellow_reviewer.id, :notification_type => PendingNotification::NEW_REVIEW, :trigger_obj_type => review.class.name, :trigger_obj_id => review.id)
            sent_to_members << fellow_reviewer
          end
        end

        # when someone reviews a story you've starred (but don't send it to the reviewer if he's the one who starred it)
        review.story.saves.map(&:member).each do |liker|
          if liker && liker.email_notification_preferences.liked_story_reviewed && !sent_to_members.include?(liker) \
            && liker != review.member
            reviewer = review.member || Member.nt_anonymous # Handle situation of a guest reviewer!
            PendingNotification.create(:local_site_id => review.local_site ? review.local_site.id : nil, :member_id => liker.id, :notification_type => PendingNotification::NEW_REVIEW, :trigger_obj_type => review.class.name, :trigger_obj_id => review.id)
            sent_to_members << liker
          end
        end
      end
    end
  rescue Exception => e
    RAILS_DEFAULT_LOGGER.error "Exception #{e} in review observer for #{review.id}; Backtrace:\n#{e.backtrace * '\n'}"
  end

end
