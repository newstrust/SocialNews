class Excerpt < ActiveRecord::Base
  belongs_to :review
  acts_as_textiled :comment
  acts_as_textiled :body
end
