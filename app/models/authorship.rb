class Authorship < ActiveRecord::Base
  belongs_to :story
  belongs_to :source, :counter_cache => 'authorships_count'
  
  # for batch_autocomplete
  def name
    source.name
  end
  def name=(name)
    self.source = Source.find_or_initialize_pending_source_by_name(name)
  end
  
end
