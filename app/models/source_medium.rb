class SourceMedium < ActiveRecord::Base
  belongs_to :source

  # Source media types
  # also see source_constants.yml
  NEWSPAPER = "newspaper"
  BLOG      = "blog"
  TV        = "tv"
  ONLINE    = "online"
  WIRE      = "wire"
  MAGAZINE  = "magazine"
  RADIO     = "radio"
  OTHER     = "other"
  
  # fairly ludicrous hack to get batch_association & Rails checkboxes to play nice
  def main_inverse=(main_inverse)
    self.main = !main_inverse
  end
end
