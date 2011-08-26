class Favorite < ActiveRecord::Base
  # polymorphic has_many :throughs... see http://blog.hasmanythrough.com/2006/4/3/polymorphic-through
  belongs_to :member
  belongs_to :favoritable, :polymorphic => :true
  belongs_to :tag, :foreign_key => "favoritable_id", :class_name => "Tag"
  
  # for batch_autocomplete
  def name
    tag.name
  end
  def name=(name)
    self.favoritable = Tag.find_or_initialize_by_name(name)
  end
  
end
