class PageView < ActiveRecord::Base
  belongs_to :session
  belongs_to :viewable, :polymorphic => true, :counter_cache => 'page_views_count'
  
  validates_uniqueness_of :session_id, :scope => [:viewable_id, :viewable_type]

  def equals(p)
    self.viewable_id == p.viewable_id && self.viewable_type == p.viewable_type && self.session_id == p.session_id
  end
end
