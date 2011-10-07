require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::InvitationsController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper

  describe "handling GET /partners/1/invitations/" do
    before(:each) do
      add_roles
      @params = { :partner_id => 1 }
    end
    
    def do_get(opts = {})
      get :index, opts
    end
    
    it "should require host access to view this action" do
      check_access_restriction(:newshound, :host) do
        do_get @params
      end
      response.should be_success
      assigns['invitations'].should_not be_empty
    end
    
    it "should redirect if the partner cannot be found" do
      login_as 'admin'
      Partner.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get @params
      response.should redirect_to(admin_partners_path)
    end
  end

  describe "handling GET /partners/1/invitations/new" do
    before(:each) do
      add_roles
      @params = { :partner_id => 1 }
    end
    
    def do_get(opts = {})
      get :new, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end    
  end
  
  describe "handling POST /partners/pledgie/invitations" do
    fixtures :all
    it_should_behave_like "A Registered Member"
    before(:each) do
      add_roles
      @partner = partners(:pledgie)
      @params = { :optional_fields => { :company => 0, :how_heard_about_us => 1 }, 
        :partner_id => @partner.to_param, 
        :id => 1, 
        :invitation => { :code => 'sekret', :invite_message => 'signed up', :email_from => 'foo@bar.com', :email_subject => 'sign up for news!', :name  => 'foo', :validation_level => 1 } }
    end
    
    def do_post(opts = {})
      post :create, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_post @params
      end
      response.should redirect_to(admin_partner_invitation_path(@partner, assigns['invitation']))
      assigns['invitation'].additional_signup_fields.include?(:how_heard_about_us).should be_true
      assigns['invitation'].additional_signup_fields.include?(:company).should be_false
      
      response.flash[:notice].should_not be_nil
    end
    
    it "should redirect if the invitation fails to be created" do
      login_as 'admin'
      do_post @params.except(:invitation)
      response.should be_success
      assigns['invitation'].errors.should_not be_empty
    end
  end
    
  describe "handling GET /partners/pledgie/invitations/1" do
    fixtures :all
    it_should_behave_like "A Registered Member"
    before(:each) do
      add_roles
      @partner = partners(:pledgie)
      @params = { :partner_id => @partner.to_param, :id => 1 }
    end
    
    def do_get(opts = {})
      get :show, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end
    
    it "should redirect if the invitation is not found" do
      login_as 'admin'
      Invitation.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get @params
      response.should redirect_to(admin_partner_invitations_path(@partner))
      response.flash[:error].should_not be_nil
    end
  end
  
  describe "handling GET /partners/pledgie/invitations/1/edit" do
    fixtures :all
    it_should_behave_like "A Registered Member"
    before(:each) do
      @partner = partners(:pledgie)
      add_roles
      @params = { :partner_id => @partner.to_param, :id => 1 }
    end
    
    def do_get(opts = {})
      get :edit, opts
    end
    
    it "should require staff access to view this action" do
      check_access_restriction(:editor, :staff) do
        do_get @params
      end
      response.should be_success
    end
    
    it "should redirect to the admin dashboard if the invitation is not found" do
      login_as 'admin'
      Invitation.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get @params
      response.should redirect_to(admin_partner_invitations_path(@partner))
      response.flash[:error].should_not be_nil
    end
  end
  
  describe "handling PUT /partners/1/invitations/1" do
    fixtures :all

    it_should_behave_like "A Registered Member"
    before(:each) do
      @partner = partners(:pledgie)
      @invitation = @partner.invitations.first
      add_roles
      @params = { :partner_id => @partner.to_param, :id => @invitation.to_param }
    end
    
    def do_put(opts = {})
      put :update, opts
    end
    
    it "should require staff access to view this action" do
      check_access_restriction(:editor, :staff) do
        do_put @params.merge(:invitation => { :invite_message => 'foo' })
      end
      response.flash[:notice].should_not be_empty
      response.should redirect_to(edit_admin_partner_invitation_path(@partner, @invitation))
    end
    
    it "should redirect to the admin dashboard if the invitation is not found" do
      login_as 'admin'
      Invitation.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_put @params
      response.should redirect_to(admin_partner_invitations_path(@partner))
      response.flash[:error].should_not be_nil
    end
    
    it "should display an error if the update uses the wrong parameters" do
      login_as 'admin'
      Partner.stub!(:find).and_return(@partner)
      # SSS: Weird .. Switching the order of these stubs breaks the stubbing.  why?  rspec bug?
      @invitation.stub!(:update_attributes).and_return(false)
      @partner.invitations.stub!(:find).and_return(@invitation)
      do_put @params.merge(:invitation => { :name => 'bar' })
      response.should be_success
      response.flash[:notice].should be_nil
    end
    
    it "should update the record" do
      login_as 'admin'
      do_put @params.merge(:optional_fields => { :company => 0, :how_heard_about_us => 1 }, :invitation => { :name => 'new name' })
      @invitation = invitations(:pledgie_save_the_rainforests_invitation) # get the new friendly id. why doesn't a simple reload work here?!
      response.should redirect_to(edit_admin_partner_invitation_path(@partner, @invitation))
      assigns['invitation'].additional_signup_fields.include?(:how_heard_about_us).should be_true
      assigns['invitation'].additional_signup_fields.include?(:company).should be_false
      assigns['invitation'].name.should == 'new name'
      assigns['invitation'].to_param.should == 'new-name'
    end
  end
  
  describe "handling DELETE /partners/pledgie/invitations/1" do
    fixtures :all

    it_should_behave_like "A Registered Member"
    before(:each) do
      @partner = partners(:pledgie)
      @invitation = @partner.invitations.first
      add_roles
      @params = { :partner_id => @partner.to_param, :id => @invitation.to_param }
    end
    
    def do_delete(opts = {})
      delete :destroy, opts
    end
    
    it "should require admin access to view this action" do
      lambda do
        lambda do
          should_be_admin_only do
            do_delete @params
          end
        end.should change(Invitation, :count).by(-1)
        @partner.invitations(true) # force the reload
      end.should change(@partner.invitations, :size).by(-1)
      response.flash[:notice].should_not be_empty
      response.should redirect_to(admin_partner_invitations_path(@partner))
      response.flash[:notice].should_not be_nil
    end
    
    it "should display an error if the invitation cannot be deleted" do
      login_as 'admin'
      Partner.stub!(:find).and_return(@partner)
      # SSS: Weird .. Switching the order of these stubs breaks the stubbing.  why?  rspec bug?
      @invitation.stub!(:destroy).and_return(false)
      @partner.invitations.stub!(:find).and_return(@invitation)
      do_delete @params
      response.flash[:error].should_not be_nil
      response.should redirect_to(admin_partner_invitations_path(@partner))
    end
  end

  describe "other sundry tests" do
    fixtures :all

    it "should change selected invitation to primary invitation" do
      p = Partner.find(1)
      add_roles
      login_as 'admin'
      put "make_primary", { :id => 1, :partner_id => 1 }
      p.reload.primary_invite.id.should == 1
      put "make_primary", { :id => 2, :partner_id => 1 }
      p.reload.primary_invite.id.should == 2
    end
  end
end
