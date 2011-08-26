class SourceRelation < ActiveRecord::Base
  belongs_to :source
  belongs_to :related_source, :class_name => "Source"
  
  # for batch_autocomplete
  def name
    related_source.name
  end
  def name=(name)
    self.related_source = Source.find_or_initialize_pending_source_by_name(name)
  end
  
end
