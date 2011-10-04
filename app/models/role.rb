class Role < Group
  set_table_name 'groups'
  has_many :memberships, :as => :membershipable, :foreign_key => :group_id

  # this is in the db, but good to have a correctly-ordered copy here.
  def self.all_slugs
    @@all_slugs ||= Role.find(:all).map(&:slug)
  end
  
  class << self
    def find(*args)
      with_scope(:find => { :conditions => ["context = ?", 'role'] }) do
        super(*args)
      end
    end
    
    def create(*args)
      options = args.extract_options!
      role = new(options)
      role.context = 'role'
      role.is_protected = true
      role.save
      role
    end
  end
  
  def before_save
    self.context = 'role'
    super
  end
end
