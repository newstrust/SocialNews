class StoryRelation < ActiveRecord::Base
  belongs_to :story
  belongs_to :related_story, :class_name => "Story"
  belongs_to :member

  after_save :update_related_story_attrs

  def equals(sr)
    self.related_story == sr.related_story && self.story == sr.story
  end
  
  # for review form and story edit form UI
  def title
    related_story.title if related_story
  end
  def title=(title)
    @rs_title = title
  end
  def url
    related_story.url if related_story
  end
  def url=(url)
    @rs_url = url
  end
  def status
    related_story.status if related_story
  end
  def status=(status)
    @rs_status = status
  end

  # overwite update_attributes to force order of update_attributes?! this is weird but should be OK.
  def update_attributes(new_attributes)
    self.related_story_id = new_attributes.delete("related_story_id") if new_attributes["related_story_id"]
    self.attributes = new_attributes
    save
  end

  protected

  def update_related_story_attrs
    rs_attrs = {}
    rs_attrs[:title]  = @rs_title if @rs_title
    rs_attrs[:url]    = @rs_url if @rs_url
    rs_attrs[:status] = @rs_status if @rs_status
    related_story.update_attributes(rs_attrs) if !rs_attrs.blank?
  end
  
end
