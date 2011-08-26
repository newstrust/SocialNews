class OpenidProfilesController < ApplicationController
  before_filter :find_member
  
  # GET /member/1/openid_profile_profiles/1
  def show
    @openid_profile = @member.openid_profiles.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  # GET /member/1/openid_profiles/new
  def new
    @openid_profile = @member.openid_profiles.build

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # POST /openid_profiles
  def create
    @openid_profile = @member.openid_profiles.build(params[:openid_profile])

    respond_to do |format|
      if @openid_profile.save
        flash[:notice] = 'Openid was successfully created.'
        format.html { redirect_to(member_openid_profile_path(@member, @openid_profile)) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  # DELETE /member/1/openid_profiles/1
  def destroy
    @openid_profile = @member.openid_profiles.find(params[:id])
    @openid_profile.destroy

    respond_to do |format|
      format.html { redirect_to(member_openid_profiles_url(@member)) }
    end
  end
  
  private
  def find_member
    @member = Member.find(params[:member_id])
  end
end
