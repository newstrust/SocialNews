class StoryClick < ActiveRecord::Base
  belongs_to :story

    # Note that this member might have already viewed the story -- in which case you get an exception.
    # Simply trap and ignore it!
  def self.record_click(story_id, sess)
    begin StoryClick.create(:story_id => story_id, :data => sess[:member_id] || sess.session_id); rescue Exception => e; end
  end
end
