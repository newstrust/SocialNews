class ProcessJob < ActiveRecord::Base
  belongs_to :processable, :polymorphic => true
  belongs_to :group
  validates_uniqueness_of :processable_id, :scope => :processable_type

  def process
    if processable
      if processor_method
        processable.send(processor_method, group)
        processable.save!
      else
        # Go the whole hog -- groups and everything!
        processable.save_and_process_with_propagation(false, group)
      end
      return true
    else
      puts "ERROR: Nil processable for #{processable_id} of type #{processable_type} for PJ #{self.id}"
      logger.error "RATING TASK: Nil processable for #{processable_id} of type #{processable_type} for PJ #{self.id}"
      return false
    end
  end
end
