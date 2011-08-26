class SaveObserver < ActiveRecord::Observer
  def after_create(save)
    story = save.story
    story_id = story.id
    save.member.social_groups.each { |g| g.add_story(story_id) }
  end

  def after_destroy(save)
    # compute only if necessary, ie. if the member is part of a social group
    story_actors = nil 

    # Find all groups from which this story should be removed
    # = all groups which don't have a submitter, reviewer, or starrer from within the group
    groups_affected = save.member.social_groups.collect { |g|
      # cache info
      if story_actors.nil?
        story = save.story
        story_actors = story.reviews.collect { |r| r.member_id } + [story.submitted_by_member.id] + story.saves.collect { |s| s.member_id }
      end
      if !Membership.exists?(:membershipable_id => g.id, :membershipable_type => 'Group', :member_id => story_actors)
        g.id 
      end
    }.compact

    GroupStory.delete_all(:story_id => save.story.id, :group_id => groups_affected) if !groups_affected.blank?
  end
end
