class Affiliation < ActiveRecord::Base
  belongs_to :member
  belongs_to :source
  
  # for batch_autocomplete
  def name
    source.name
  end
  def name=(name)
    self.source = Source.find_or_initialize_pending_source_by_name(name)
  end
  
end
