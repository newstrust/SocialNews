class PendingNotification < ActiveRecord::Base
  belongs_to :local_site
  belongs_to :member
  belongs_to :trigger_obj, :polymorphic => :true

  QUOTE_LINK    = "quote:link"
  NEW_REVIEW    = "review:new" # Review of a story I submitted / reviewed / starred
  STORY_EDIT    = "story:edit"
  STORY_COMMENT = "story:comment"
end
