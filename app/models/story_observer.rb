class StoryObserver < ActiveRecord::Observer
  def before_save(story)
    @old_submitter = new_record? ? nil : story.submitted_by_member
  end

  def after_save(story)
    # FIXME: For the submitter who lost the credit, we need to update this story's group presence for all the social groups the submitter belongs to.
    # FIXME: The current code below assumes that submitter info is not changed from one member to another.
    # if submitter information changed, update group stories for this story
    new_submitter = story.submitted_by_member
    if @old_submitter != new_submitter && new_submitter != Member.nt_bot
      story_id = story.id
      story.submitted_by_member.social_groups.each { |g| g.add_story(story_id) }
    end
  end
end
