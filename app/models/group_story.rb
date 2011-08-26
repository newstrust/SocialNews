class GroupStory < ActiveRecord::Base
  belongs_to :group
  belongs_to :story

  after_create :process_story

  def process_story
    # Ensure that group ratings for this story will be computed by adding it to the background rating computation queue
    self.story.process_in_background(self.group)
  end
end
