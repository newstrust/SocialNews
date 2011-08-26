# Assignment of a editorial block to a editorial space on the homepage / subject page / topic page 
class EditorialBlockAssignment < ActiveRecord::Base
  belongs_to :editorial_space
  belongs_to :editorial_block

  def self.find_block_assignment(local_site, block_id, page_type, page_id)
    eba = EditorialBlockAssignment.find(:first,
                                  :joins => [:editorial_space],
                                  :conditions => {"editorial_spaces.page_type" => page_type.blank? ? nil : page_type,
                                                  "editorial_spaces.page_id" => page_id.blank? ? nil : page_id.to_i,
                                                  "editorial_spaces.local_site_id" => local_site ? local_site.id : nil,
                                                  :editorial_block_id => block_id})
  end
end
