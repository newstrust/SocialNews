require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::PartnersController do
  include AuthenticatedTestHelper
  include RolesystemTestHelper

  describe "handling GET /admin/partners" do
    before(:each) do
      add_roles
      @partner  = mock(Partner, :name => 'Pledgie')
      @params = {}
    end
    
    def do_get(opts = {})
      get :index, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end
    it "should return a paginated list of partners" do
      Partner.stub!(:paginate).and_return([@partner])
      login_as 'admin'
      do_get
      response.should be_success
      assigns['partners'].first.name =~ /Pledgie/
    end
  end

  describe "handling GET /adming/partners/new" do
    before(:each) do
      add_roles
      @params = { :id => 1 }
    end
    
    def do_get(opts = {})
      get :new, opts
    end
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
    end
  end
  
  describe "handling POST /admin/partners" do
    before(:each) do
      add_roles
      @params = { :partner => { :name => 'NPR' } }
    end
    
    def do_post(opts = {})
      post :create, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_post @params
      end
    end
    
    it "should create a new partner" do
      login_as 'admin'
      lambda do
        do_post @params
      end.should change(Partner, :count).by(1)
      
      response.should redirect_to(admin_partner_path(assigns['partner']))
    end

    it "should return an error if incorrect parameters are supplied" do
      login_as 'admin'
      do_post {}
      response.should render_template('new')
      assigns['partner'].errors.should_not be_empty
    end
  end
  
  describe "handling GET /admin/partners/1" do
    before(:each) do
      add_roles
      @params = { :id => 1 }
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
    
    it "should redirect to the admin dashboard if incorrect parameters are supplied" do
      login_as 'admin'
      do_get @params.except(:id)
      response.should redirect_to(admin_partners_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should redirect to the admin dashboard if the partner is not found" do
      login_as 'admin'
      Partner.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get @params
      response.should redirect_to(admin_partners_path)
      response.flash[:error].should_not be_nil
    end
  end
  
  describe "handling GET /admin/partners/1/edit" do
    before(:each) do
      add_roles
      @partner = Partner.find(:first) #mock(Partner, :id => 1, :name => 'Pledgie')
      @params = { :id => @partner.id }
    end
    
    def do_get(opts = {})
      get :edit, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_get @params
      end
      response.should be_success
    end
    
    it "should redirect to the admin dashboard if incorrect parameters are supplied" do
      login_as 'admin'
      do_get @params.except(:id)
      response.should redirect_to(admin_partners_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should redirect to the admin dashboard if the partner is not found" do
      login_as 'admin'
      Partner.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_get @params
      response.should redirect_to(admin_partners_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should display the requested partner" do
      Partner.stub!(:find).and_return(@partner)
      login_as 'admin'
      do_get @params
      response.should be_success
      assigns['partner'].name.should == @partner.name
    end
  end
  
  describe "handling PUT /admin/partners/1" do
    before(:each) do
      add_roles
      @partner = mock_model(Partner, :id => 1, :update_attributes => true, :update_attribute => false, :name => 'My Partner', :valid? => true )
      Partner.stub!(:find).and_return(@partner)
      @params = { :id => 1, :partner => { :name => 'foo' }}
    end
    
    def do_put(opts = {})
      put :update, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_put @params
      end
      response.should redirect_to(edit_admin_partner_path(@partner))
    end
    
    it "should update the selected partner" do
      login_as 'admin'
      do_put
      response.should redirect_to(edit_admin_partner_path(@partner))
      response.flash[:notice].should_not be_nil
      assigns['partner'].name.should == @partner.name
    end
    
    it "should redirect to the partner index if the partner is not found" do
      login_as 'admin'
      Partner.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_put @params
      response.should redirect_to(admin_partners_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should return an error if incorrect parameters are supplied" do
      @partner.stub!(:valid?).and_return(false)
      login_as 'admin'
      do_put
      response.flash[:notice].should be_nil
      response.should be_success
    end
  end
    
  describe "handling DELETE /admin/partners/1" do
    before(:each) do
      add_roles
      @partner.stub!(:destroy).and_return(true)
      Partner.stub!(:find).and_return(@partner)
      @params = { :id => 1 }
    end
    
    def do_delete(opts = {})
      delete :destroy, opts
    end
    
    it "should require admin access to view this action" do
      should_be_admin_only do
        do_delete @params
      end
      response.should redirect_to(admin_partners_path)
    end
    
    it "should delete the requested partner" do
      login_as 'admin'
      do_delete
      response.flash[:notice].should_not be_nil
      response.should redirect_to(admin_partners_path)
    end
    
    it "should redirect to the partner index if the partner is not found" do
      login_as 'admin'
      Partner.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      do_delete @params
      response.should redirect_to(admin_partners_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should redirect to edit if the partner is protected and cannot be deleted" do
      login_as 'admin'
      @partner.stub!(:errors).and_return(mock('errors', :full_messages => ['error']))
      @partner.stub!(:destroy).and_return(false)
      do_delete @params
      response.should redirect_to(edit_admin_partner_path(@partner))
    end
  end
end
