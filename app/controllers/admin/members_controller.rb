# This class allows access from several different contexts depending on how the routes are bing drawn.
# Sometimes this class may require a parent model, in which case a @parent instance variable will be created.

class Admin::MembersController < Admin::AdminController
  before_filter { |controller| controller.send(:find_containing_group) if controller.request.parameters['group_id'] }
  before_filter :find_member, :except => [:new, :index, :admin_actions, :create, :search, :join, :host_index, :spammer_termination_form, :terminate_spammers]
  before_filter :find_hostable, :only => [:host_index, :host, :unhost]
  layout 'admin'
  
  # GET /admin/members
  # GET /admin/groups/1/members
  # GET /admin/groups/1/members/index.js
  def index
    if @parent
      @members = @parent.members.paginate(:all, pagination_params)
    else
      @members = Member.paginate(:all, pagination_params)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.js do
        render :inline => members_to_json(@members)
      end
    end
  end
  
  # GET/admin/members/search
  def search
    params[:id] = params[:q] if params[:q] # Autocomplete plugin uses q as a param but we want id
    @results = []
    @results = Member.search(params[:id])  unless empty_query?
    respond_to do |format|
      format.js do
        render :json => @results.map {|x| "#{x.name}|#{x.email}|#{x.id}" }.compact.join("\n").to_json
      end
    end
  end

  def admin_actions
  end

  # GET /admin/members/
  #
  def spammer_termination_form
  end

  def terminate_spammers
    spammer_ids = params[:ids].split(",")
    @spammers = Member.find(:all, :conditions => ["id in (?)", spammer_ids])
    @hidden_stories = []
    @recalc_stories = []
    @other_spammers = []
    @rejected_terminations = []
    @spammers.each { |m|
      if m.validation_level >= SocialNewsConfig["min_trusted_member_validation_level"].to_i
        @rejected_terminations << m
        next
      end

        # mark member deleted
        # add members ip address to spammer ip addresses
        # hide all submitted stories
        # queue all reviewed stories for re-processing
      old_status = m.status
      m.update_attributes({:status => Member::TERMINATED, :edit_notes => (m.edit_notes || "") + "<br/>Terminated by #{current_member.name} @ #{Time.now.strftime("%Y/%m/%d")}"})
      Story.find_all_by_submitted_by_id(m.id).each { |s| s.update_attribute(:status, Story::HIDE); @hidden_stories << s }
      m.reviews.each { |r|
        rstory = r.story
        # Just recording list of recalced stories because the member after save callback takes care of queuing stories for recalc.
        @recalc_stories << rstory if !r.hidden? && r.include_rating? && rstory.is_public?
      }

        # Find other members (with guest / member status) that share their IP with this spammer
      if m.http_x_real_ip
        # Don't increment counter if member had already been deleted
        if old_status != Member::TERMINATED
          ip = SpammerIp.find_or_create_by_ip(m.http_x_real_ip)
          ip.spammer_count = ip.spammer_count ? ip.spammer_count + 1 : 1
          ip.save!
        end
        @other_spammers += Member.find(:all,
                                       :include => [:member_attributes, :slugs],
                                       :joins => "JOIN member_attributes ON member_attributes.member_id=members.id AND member_attributes.name='http_x_real_ip' AND member_attributes.value = '#{m.http_x_real_ip}'",
                                       :conditions => ["status in (?)", [Member::MEMBER, Member::GUEST]])
      end
    }
    @other_spammers.uniq!
    @other_spammers.reject! { |s| s.status == Member::TERMINATED }
    @recalc_stories.uniq!
  end

  # GET /admin/members/reinvite
#  def reinvite
#  end

  # POST /admin/members/reinvite
#  def send_reinvites
#  end

  # GET /admin/members/new
  # GET /admin/groups/1/members/new  
  def new
    @member = Member.new
  end

  # POST /admin/members/
  def create
  end
  
  # GET /admin/members/1/edit
  # GET /admin/groups/1/members/1/edit
  def edit
  end

  # PUT /admin/members/1
  # PUT /admin/groups/1/members/1
  def update
  end
  
  # DELETE /admin/members/1
  def destroy
  end
  
  # POST /admin/groups/1/members/join
  def join
    @member = Member.find(params[:id])
    if @group.add_member(@member)
      flash[:notice] = "The member has joined the group."
    else
      flash[:error] = "The member could not join the group."
    end
    respond_to do |format|
      format.html { redirect_to(admin_group_members_path(@group)) }
      format.js do
        render :nothing => true, :status => '406' and return if flash.has_key?(:error)
        render :nothing => true, :status => '200' and return if flash.has_key?(:notice)
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    respond_to do |format|
      format.html { redirect_to(admin_group_members_path(@group)) }
      format.js { render :nothing => true, :status => '500'}
    end
  end
  
  # DELETE /admin/groups/1/members/1/leave
  def leave
    if @group.members.delete(@member)
      flash[:notice] = "The member has been removed from the group" 
    else
      flash[:error] = "The member could not be removed from the group."
    end
    
    respond_to do |format|
      format.html { redirect_to(admin_group_members_path(@group))}
      format.js { render :inline => members_to_json(@group.members) }
    end
  end

  # POST /admin/members/hosts/:hostable_type/:hostable_id/join.:format
  def host
    @member = Member.find(params[:id])

    # Topics & Subjects have local-site specific hosts
    ls = ["subject", "topic"].include?(params[:hostable_type]) ? @local_site : nil
    if @hostable.add_host(@member, ls)
      flash[:notice] = "#{@hostable.name} is now hosted by #{@member.name}"
    else
      flash[:error] = "#{@hostable.name} can not be hosted by #{@member.name}"
    end
    respond_to do |format|
      format.js do
        render :nothing => true, :status => '406' and return if flash.has_key?(:error)
        render :nothing => true, :status => '200' and return if flash.has_key?(:notice)
      end
    end
  end
  
  # DELETE /admin/members/hosts/:hostable_type/:hostable_id/:id/leave.:format
  def unhost
    # Topics & Subjects have local-site specific hosts
    ls = ["subject", "topic"].include?(params[:hostable_type]) ? @local_site : nil
    if @hostable.remove_host(@member, ls)
      flash[:notice] = "#{@member.name} is no longer a host of #{ls.name if ls} #{@hostable.name}"
    else
      flash[:error] = "Could not remove #{@member.name} as a host of #{ls.name if ls} #{@hostable.name}"
    end
    respond_to do |format|
      format.html { redirect_to(admin_path)}
      format.js { render :inline => members_to_json(@hostable.hosts(@local_site)) }
    end
  end
  
  # GET /admin/members/hosts/:hostable_type/:hostable_id.:format
  def host_index
    respond_to do |format|
      format.js { render :inline => members_to_json(@hostable.hosts(@local_site)) }
    end
  end
  
  protected
  
    def find_member
      @member = @group.members.find(params[:id]) if @group
      @member = Member.find(params[:id])
    rescue ActiveRecord::RecordNotFound => e
      flash[:error] = e.message
      if @group
        redirect_to(admin_group_members_path(@group))
      else
        redirect_to(admin_members_path)
      end
    end
    
    def find_hostable
      hostable_class = self.class.const_get(params[:hostable_type].camelize)
      @hostable = hostable_class.find(params[:hostable_id])
    # rescue NameError, ActiveRecord::RecordNotFound
    end
    
  private
    
    def members_to_json(members)
      members.map {|x| Hash['login', x.login,'name', x.name, 'email', x.email, 'id', x.id] }.to_json
    end
    
end
