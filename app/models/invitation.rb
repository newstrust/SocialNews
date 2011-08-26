require 'ostruct'
require 'erb'
class Invitation < ActiveRecord::Base  
  acts_as_textiled :landing_page_template, :welcome_page_template, :success_page_template

  has_friendly_id :name, :use_slug => true
  belongs_to :partner
  belongs_to :group
  
  validates_presence_of :partner_id, :validation_level, :name, :email_from, :email_subject, :code, :invite_message
  validates_numericality_of :validation_level

  # Disabled so you can use email ids of the form "<AppName> blah@xyz.com"
  # validates_format_of :email_from, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
 
  attr_accessible :code, :name, :validation_level, :landing_page_template, :invite_message, :welcome_page_template, :success_page_template
  attr_accessible :additional_signup_fields, :email_from, :email_subject, :success_page_link, :welcome_page_link, :landing_page_link
  attr_accessible :widget_newshunt_topic, :widget_newshunt_url, :widget_newshunt_title, :widget_newshunt_desc, :group_id

  before_save :validate_templates_and_signup_fields
  attr_accessor :signup_fields
  #:referred_by was removed from list of optional fields below... conflict between expecting a member ID vs a string
  @@optional_fields = [:how_heard_about_us, :company, :home_page, :news_experience, :internet_experience, :politics] 
  cattr_reader :optional_fields
  
  def additional_signup_fields
    asf = Marshal.load(self[:additional_signup_fields]) if self[:additional_signup_fields]
    asf || []
  end

  def additional_signup_fields=(x)
    if x
      x = [x].flatten
      self.signup_fields = x.map { |f| f.to_sym }
      validate_additional_signup_fields
    end
  end
  
  def additional_signup_fields_to_struct
    hash = {}
    self.additional_signup_fields.map do |k|
      hash[k] = 1
    end if self.additional_signup_fields
    @optional_fields = OpenStruct.new(hash)
  end

  def update_additional_signup_fields(obj)

    # We expect a hash of keys with values of 0 or 1 sent to us.
    self.additional_signup_fields = obj.reject{ |key, value| value.to_i < 1 }.keys
    self.save
  end
  
  def validate_templates_and_signup_fields
    
    # This way we don't clobber each other's exceptions
    (validate_additional_signup_fields) ? validate_templates_and_links : false
  end
  
  def validate_templates_and_links
    ["landing_page", "welcome_page", "success_page"].each do |f|
      raise(ArgumentError, "You cannot use both a template and a link for #{f}") if !self["#{f}_link"].blank? && !self["#{f}_template"].blank?
    end
  rescue ArgumentError => e
    self.errors.add_to_base(e.message)
    false
  end
  
  def validate_additional_signup_fields
    fields = []
    self.signup_fields.each do |key|
      raise(ArgumentError, "Invalid Key Type") unless @@optional_fields.include?(key)
      fields <<  key
    end if self.signup_fields
    self[:additional_signup_fields] = Marshal.dump(fields)
  rescue ArgumentError => e
    self.errors.add_to_base(e.message)
    false
  end
  
  class << self
    def format_invitation_email(member, invitation, invite_link)
      email_text = invitation.invite_message
      keys = { 
        :member_first_name => member.name.split(' ').first, 
        :member_name => member.name, 
        :member_email => member.email, 
        :member_password => member.password,
        :invite_link => invite_link
      }
      keys.each_pair do |k,v|
        email_text = email_text.gsub("[#{k.to_s.gsub("member_",'MEMBER.').upcase}]",v)
      end
      email_text
    end
  end
end
