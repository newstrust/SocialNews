require File.dirname(__FILE__) + '/../spec_helper'

describe Invitation do
  fixtures :all
  before(:each) do
    @pledgie = partners(:pledgie)
    @moveon = partners(:moveon)
    @invitation = @pledgie.invitations.first
  end
  
  it "should require a valid invite email to be created before saving" do
    lambda do
      @invite = @pledgie.invitations.create(:name => 'foo', :validation_level => 10)
      @invite.errors.on(:email_from)
      @invite.errors.on(:email_subject)
      @invite.errors.on(:code)
    end.should_not change(Invitation, :count)
  end
  
  it "should allow a partner to have many invitations" do
    @pledgie.invitations.count.should == 2
  end
  
  it "should allow erb in templates" do
    @invitation.landing_page_template =<<EOF
<%= "foo" %>
<% 10.times do |x| %>
<%= x %>
<% end %>
EOF
    # SSS: this test needs fixing -- this used to be part of the invitation model
    # but has been moved to a helper since because of weird bugs introduced elsewhere
    # on the site because of having to load action view helpers in the model
    attr_with_erb_to_html(@invitation, :landing_page_template).should =~ /<p>foo<\/p>/

    # Should catch exceptions too
    @invitation.landing_page_template ="<%= foo %>"
    @invitation.attr_with_erb_to_html(:landing_page_template).should =~ /NameError in ERB for landing_page_template: undefined local variable or method `foo/
  end
  
  it "should replace the template variables before sending the activation message" do
    template = <<TEXT
 _Let's replace these variables shall we?_
* First Name: [MEMBER.FIRST_NAME]
* Full Name: [MEMBER.NAME]
* Invitation Link: [INVITE_LINK]
* Email: [MEMBER.EMAIL]
* Password: [MEMBER.PASSWORD]
TEXT
    member = members(:heavysixer)
    invite = invitations(:pledgie_save_the_rainforests_invitation)
    invite.update_attribute(:invite_message, template)
    member.accept_invitation(invite)
    member.password = "foobarbaz"
    url = "http://#{SocialNewsConfig["app"]["domain"]}/members/activate/#{invite.slug.name}"
    response = Invitation.format_invitation_email(member, invite, url)
    
    # Email should replace template variables
    ["[MEMBER.FIRST_NAME]", "[MEMBER.NAME]", "[INVITE_LINK]", "[MEMBER.EMAIL]", "[MEMBER.PASSWORD]"].each do |k|
      response.should_not =~ /#{Regexp.escape(k)}/
    end
    response.should =~ /#{member.password}/
    response.should =~ /#{member.email}/
    response.should =~ /#{member.name}/
    response.should =~ /#{url}/
    
  end
  
  it "should require the validation_level and partner id" do
    lambda do
      @invitation = Invitation.create
      @invitation.errors.on(:name).should_not be_empty
      @invitation.errors.on(:validation_level).should_not be_empty
      @invitation.errors.on(:partner_id).should_not be_empty
    end.should_not change(Invitation, :count)
  end
  
  it "should serialize data stored in the additional signup fields." do
    # nil is ok
    @invitation.additional_signup_fields = nil
    @invitation.save.should be_true
    
    # Using unrecognized fields.
    @invitation.additional_signup_fields = [:foo, :baz]
    @invitation.save.should be_false
    @invitation.errors.on(:base).should =~ /Invalid Key Type/
    @invitation.errors.clear
    
    # Save using the correct fields
    @invitation.additional_signup_fields = [:how_heard_about_us, :company]
    @invitation.save.should be_true
    @invitation.additional_signup_fields.include?(:how_heard_about_us).should be_true
    @invitation.additional_signup_fields.include?(:company).should be_true
  end
  
  it "some fields should support textile" do
    desc_html    = '<p>Yay _ for _  <i>textile</i></p>'
    desc_textile = 'Yay _ for _  __textile__'
    desc_plain   = 'Yay _ for _  textile'
    
    %w(landing_page_template welcome_page_template).each do |attribute|
      @invitation.update_attribute(attribute.to_sym, desc_textile)
      @invitation.reload
      desc_html.should =~ /#{@invitation.send(attribute.to_sym)}/
      @invitation.send(attribute.to_sym, :source).should == desc_textile
      @invitation.send(attribute.to_sym, :plain).should == desc_plain
      
      @invitation.send("#{attribute}_source".to_sym).should == desc_textile
      @invitation.send("#{attribute}_plain".to_sym).should == desc_plain
      
      # make sure we don't overwrite anything - thanks James
      desc_html.should =~ /#{@invitation.send(attribute.to_sym)}/
      @invitation.send(attribute.to_sym, :source).should == desc_textile
      @invitation.send(attribute.to_sym, :plain).should ==  desc_plain      
    end
  end
  
  it "should allow you to use either a template or a link but not both" do
    ["landing_page_", "welcome_page_", "success_page_"].each do |f|
      lambda do
        @invitation = @pledgie.invitations.build(:code => 'foo', :name => 'foo', :validation_level => 10, :email_from => 'foo@bar.com', :email_subject => 'you are signed up', :invite_message => 'signed up')
        @invitation["#{f}link"] ="http://www.google.com"
        @invitation["#{f}template"] = "my template"
        @invitation.save.should be_false
        @invitation.errors.on(:base).should_not be_empty
      end.should_not change(Invitation, :count)
    end
  end
  
  # Right now friendly_id does not allow for a scoping parameter, which means no two models of the same
  # class can have the smae name even if they are scoped by other means.
  it "should create a slug unique to the partner"
end
