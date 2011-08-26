class PageHost < ActiveRecord::Base
  belongs_to :member
  belongs_to :local_site
end
