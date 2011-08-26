class EditorialSpace < ActiveRecord::Base
  belongs_to :local_site
  belongs_to :page, :polymorphic => true
  has_many :editorial_block_assignments, :dependent => :delete_all
  has_many :editorial_blocks, :through => :editorial_block_assignments 

  named_scope :on_homepage, lambda { |ls| { :conditions => {:page_id => nil, :local_site_id => ls ? ls.id : nil} } }
  named_scope :on_landing_page, lambda { |ls, p| { :conditions => {:page_type => p ? p.class.name : nil, :page_id => p ? p.id : nil, :local_site_id => ls ? ls.id : nil} } }
  named_scope :on_non_homepage, lambda { |ls, pt, pi| { :conditions => {:page_type => pt, :page_id => pi.to_i, :local_site_id => ls ? ls.id : nil } } }

  after_save :update_ebas

  def page_name
    page.blank? ? "Homepage" : "#{page.class.name} #{page.name}"
  end

  def page_opts
    page.blank? ? {} : {:page_id => page.id, :page_type => page.class.name}
  end

  def editorial_block_slugs
    self.editorial_blocks.map(&:slug) * ', '
  end

  def editorial_block_slugs=(slugs)
    @editorial_block_slugs = slugs
  end

  protected

  def update_ebas
    self.editorial_blocks = EditorialBlock.find_all_by_slug(@editorial_block_slugs.split(",").map(&:strip)) if !@editorial_block_slugs.nil?
  end
end
