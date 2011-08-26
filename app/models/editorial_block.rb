class EditorialBlock < ActiveRecord::Base
  has_many :editorial_block_assignments, :dependent => :delete_all
  has_many :editorial_spaces, :through => :editorial_block_assignments 

  PRE_BAKED_BLOCK_SLUGS = ["news_comparison", "recent_reviews", "recent_reviewers", "group_members", "featured_review", "group_signup_badge"]

  def is_prebaked?
    PRE_BAKED_BLOCK_SLUGS.include?(slug)
  end
end
