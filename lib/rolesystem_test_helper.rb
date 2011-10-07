module RolesystemTestHelper
  def self.all_mock_roles
    ["admin", "staff", "editor", "host", "newshound", "content_editor"]
  end

  def add_roles
    RolesystemTestHelper.all_mock_roles.each do |rs|
      instance_variable_set("@#{rs}_role".to_sym, mock_model(Group, :name => rs.to_s.humanize, :context => 'role', :slug => rs, :add_member => true))
    end
    @group = mock_model(Group, :name => 'Watchdogs', :add_member => true)
  end

  def login_as(role)
    instance_variable_set("@#{role}".to_sym, MockMember.new(:roles => [instance_variable_get("@#{role}_role")]))
    @controller.stub!(:current_member).and_return(instance_variable_get("@#{role}"))
  end  

  def check_access_restriction(failure_role, success_role)
    if block_given?
      login_as(failure_role)
      yield
      
      if request.format.to_sym == :js
        response.status.should == "401 Unauthorized"
      else
        response.should redirect_to(access_denied_path)
      end

      login_as success_role
      yield
    end
  end

  def should_be_admin_only(*args)
    check_access_restriction(args[0].blank? ? "editor" : args[0], "admin") { yield }
  end
end
