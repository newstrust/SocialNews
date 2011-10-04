class PageHost < ActiveRecord::Base
  # SSS: bad code -- this could be removed now since this feature is not needed anymore
  belongs_to :member
  belongs_to :local_site
  has_one :hosting
end
