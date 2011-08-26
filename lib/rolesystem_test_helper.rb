module RolesystemTestHelper
  def add_roles
    @group = mock_model(Group, :name => 'Watchdogs', :add_member => true)
    @editor_role = mock_model(Group, :name => 'editor', :context => 'role', :slug => "editor", :add_member => true)
    @admin_role = mock_model(Group, :name => 'admin', :context => 'role', :slug => "admin", :add_member => true)
    @content_editor_role = mock_model(Group, :name => 'content_editor', :context => 'role', :slug => "content_editor", :add_member => true)
  end

  def login_as(role)
    instance_variable_set("@#{role}".to_sym, MockMember.new(:roles => [instance_variable_get("@#{role}_role")]))
    @controller.stub!(:current_member).and_return(instance_variable_get("@#{role}"))
  end  

  def should_be_admin_only(*args)
    access_level = args[0].blank? ? 'editor' : args[0]
    if block_given?
      login_as(access_level)
      yield
      
      if request.format.to_sym == :js
        response.status.should == "401 Unauthorized"
      else
        response.should redirect_to(access_denied_path)
      end
      login_as 'admin'
      yield
    end
  end
end
