class Admin::AdminController < ApplicationController
  before_filter :login_required
  grant_access_to :admin
  
  def find_containing_group
    @parent_sym = :group
    @parent = find_group(params[:group_id])
  end
  
  def access_denied
    flash[:error] = "Access Denied"
    respond_to do | format |
      format.html { 
        current_member ? redirect_to(access_denied_path) : redirect_to(new_sessions_path)
      }
      format.js do 
        render :nothing => true, :status => 401 
      end
    end
  end

  def check_admin_access
    redirect_to access_denied_url and return unless logged_in? && current_member.has_role_or_above?(:admin)
  end

  def check_staff_access
    redirect_to access_denied_url and return unless logged_in? && current_member.has_role_or_above?(:staff)
  end

  def check_edit_access(override_role=:editor)
    # Only editors and quote hosts get edit access to an individual quote
    redirect_to access_denied_url and return unless logged_in? && current_member.has_host_privilege?(@group, override_role, @local_site)
  end
  
  def find_group(the_id = nil)
    the_id = params[:id] if the_id.nil?
    @group = Group.find(the_id)
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to(admin_groups_path) and return false
  end
end
