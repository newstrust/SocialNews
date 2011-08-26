class ProcessedRatingVersion < ActiveRecord::Base
  belongs_to :processable, :polymorphic => true
end
