class Discussions::CommentsController < ApplicationController
  before_filter :login_required, :except => [ :index, :show, :sort ]
  all_access_to :except => [:new]
  before_filter :find_comment, :except => [:index, :new, :create, :show, :reply, :sort]
  
  # GET /discussions/comments
  def index
    @sticky_params = pagination_params
    @sticky_params[:filter_by] = params[:filter_by] || "none"
    records = case @sticky_params[:filter_by].downcase
      when 'topics'
        # For the purpose of the view subjects and topics should be considered the same.
        Topic.commentable.find(:all, :conditions => {:local_site_id => @local_site ? @local_site.id : nil}, :select => 'id, name, type, slug')
      when 'sources'
        Source.commentable.find(:all, :select => 'id, name, slug')
      else
        Topic.commentable.find(:all, :conditions => {:local_site_id => @local_site ? @local_site.id : nil}, :select => 'id, name, type, slug') + 
        Source.commentable.find(:all, :select => 'id, name, slug') +
        Comment.find(:all, :conditions => { :parent_id => nil, :commentable_type => nil, :commentable_id => nil })
    end
    @records = WillPaginate::Collection.create(pagination_params[:page], pagination_params[:per_page], records.size) do |pager|
      offset = (pagination_params[:page].to_i * pagination_params[:per_page].to_i) - pagination_params[:per_page].to_i
      limit = ([offset + pagination_params[:per_page].to_i, records.size].min) - 1
      pager.replace(records[offset..limit]||[])
    end

    # Comment.visible.top.sources.paginate(:all, pagination_params)
    respond_to do |format|
      format.html # index.html.erb
    end
  end

  # GET /discussions/comments/1
  def show
    @comment = Comment.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.json do
        @thread = @template.comment_thread_for([@comment.root])
        render :json => { :thread => @thread, :comment => @comment.for_json }, :status => 200
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to discussions_comments_path
  end

  # GET /discussions/comments/new
  def new
    unless current_member.can_comment?
      # flash[:notice] = "Commenting is open to all members with a level of #{SocialNewsConfig["min_member_rating_for_comments"]} or more.<br/>Read our #{help_link('FAQ', "member_levels", "member")} for more info."
      flash[:notice] = current_member.muzzled? ? "Your commenting privileges have been revoked. Please #{validation_email_url} to re-enable commenting privileges." : "Your account must be validated before you can post a comment. To have your account validated, please review two stories on our site, then #{validation_email_url}.  <a href='/help/faq/member/#member_profile_why_validation'>Click here</a> to learn about account validation and member levels."
      redirect_to member_path(current_member) and return false
    end

    @comment = current_member.comments.build
    @comment.commentable_type = params[:commentable_type] if params[:commentable_type]
    @comment.commentable_id = params[:commentable_id] if params[:commentable_id]
    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # GET /discussions/comments/1/edit
  def edit
    raise ActiveRecord::RecordNotFound unless @comment.can_be_edited_by?(current_member)
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = "Comment Could Not Be Found"
    redirect_to discussions_comments_path
  end

  # POST /discussions/comments
  def create
    if params[:comment][:body].blank?
      respond_to do |format|
        format.json do
          render :json => { :error => "Please enter the body of the comment", :status => 200 } and return
        end
        format.html do
          flash[:error] = "Please enter the body of the comment"
          @comment = Comment.new(params[:comment])
          redirect_to(redirect_for(@comment)) and return
        end
      end
    end

    @comment = current_member.comments.build(params[:comment])
    respond_to do |format|
      if @comment.save
        @comment.deliver_notifications

        flash[:notice] = 'Thanks for the comment!'
        format.html do
          redirect_to(redirect_for(@comment))
        end

        format.json do
          @comment_count = @comment.commentable_type.constantize.find(@comment.commentable_id).comments.count
          @html = case @comment.commentable_type
            when 'Review'
              @review = Review.find(@comment.commentable_id)
              render_to_string(:partial => '/reviews/comments.html.erb', :locals => { :review => @review })
            else
              @comment.parent.nil? ? render_to_string(:partial => 'discussions/comments/comment.html.erb', :locals => { :index => 0, :comment => @comment, :hostable => nil}) : @template.comment_thread_for([@comment.parent])
          end
          response_hash = { :total_comments => @comment_count, :html => @html, :comment => @comment.for_json, :flash => flash, :status => 200 }
          response_hash.merge!(:parent => @comment.parent.for_json) if @comment.parent
          render :json => response_hash
          flash.discard
        end
      else
        @parent = Comment.find(params[:parent][:id]) if params[:parent] && params[:parent][:id]
        format.html { render :action => "new" }
        format.json do
           render :json => { :error => true, :flash => { :error => @comment.errors.to_sentence }, :status => 200 } 
         end
      end
    end
  end

  # GET /discussions/comments/1/reply
  def reply
    unless current_member.can_comment?
      # flash[:notice] = "Commenting is open to all members with a level of #{SocialNewsConfig["min_member_rating_for_comments"]} or more.<br/>Read our #{help_link('FAQ', "member_levels", "member")} for more info."
      flash[:notice] = current_member.muzzled? ? "Your commenting privileges have been revoked. Please #{validation_email_url} to re-enable commenting privileges." : "Your account must be validated before you can post a comment. To have your account validated, please review two stories on our site, then #{validation_email_url}.  <a href='/help/faq/member/#member_profile_why_validation'>Click here</a> to learn about account validation and member levels."
      redirect_to member_path(current_member) and return false
    end

    @parent = Comment.find(params[:id])
    @comment = current_member.comments.build(:initial_ancestor_id => @parent.id)
    @comment.commentable_type = @parent.commentable_type
    @comment.commentable_id = @parent.commentable_id
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to discussions_comments_path
  end

  # PUT /discussions/comments/1
  def update
    raise ActiveRecord::RecordNotFound unless @comment.can_be_edited_by?(current_member)
    respond_to do |format|
      params[:comment][:last_edited_by_id] = current_member.id if params[:comment]

      # Delete these attributes before save otherwise it'll mess up the STI for classes like Subject.
      params[:comment].delete(:commentable_type) if params[:comment] && params[:comment][:commentable_type]
      params[:comment].delete(:commentable_id) if params[:comment] && params[:comment][:commentable_id]

      if @comment.can_be_edited_by?(current_member) && @comment.update_attributes(params[:comment])
        flash[:notice] = 'Comment was successfully updated.'
        format.html { redirect_to(redirect_for(@comment)) }
        format.json do
          response_hash = { :comment => @comment.for_json.merge(:body_source => @comment.body(:source)), :flash => flash, :status => 200 }
          response_hash.merge!(:parent => @comment.parent.for_json) if @comment.parent
          render :json => response_hash
          flash.discard
        end
      else
        format.html { render :action => "edit" }
        format.json do
           unless @comment.can_be_edited_by?(current_member)
             errors = "You can no longer edit this comment."
           else
             errors = @comment.errors.to_a.inject([]){|x,a| x << "#{a[0].humanize} #{a[1]}".downcase.capitalize}.to_sentence
           end
           render :json => { :flash => { :error => errors }, :comment => @comment.for_json.merge(:body_source => @comment.body(:source)), :status => 200 } 
           flash.discard
         end
      end
    end
  end

  def sort
    opts = { :include => [:replies] }
    @record = params[:klass].constantize.find(params[:id], :include => [:comments])
    @comments = case params[:filter_by]
    when 'oldest'
      @record.comments.top.paginate(:all, pagination_params(:order => 'created_at ASC'))
    when 'newest'
      @record.comments.top.paginate(:all, pagination_params(:order => 'created_at DESC'))
    end

    respond_to do |format|
      unless @comments.empty?
        @thread = "#{@template.comment_page_for(@comments, :current_page => @comments.current_page)}"
      else
        @thread = "<h4 style='margin:10px'>No comments yet#{current_member && current_member.can_comment? ? "&mdash;be the first to comment." : ""}</h4>"
      end
      @pagination = %Q(
      <div style="padding-top:6px; padding-bottom:0;">
        #{@template.will_paginate(@comments, :renderer => ThreadedCommentsLinkRenderer, :next_label => 'More Comments')}
      </div>
      )
      format.json do 
        render :json => {
          :total_comments => @record.comments.count,
          :current_page => @comments.current_page,
          :total_pages => @comments.total_pages,
          :total_entries => @comments.total_entries,
          :per_page => @comments.per_page,
          :thread => @thread, 
          :pagination => @pagination }.to_json , :status => 200
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    respond_to do |format|
      format.json do
        render :json => flash.to_json
        flash.discard
      end
    end
  end

  # GET /discussions/comments/1/confirm_delete
  def confirm_delete
    flash[:notice] = "Are you sure you want to remove this comment?"
    respond_to do |format|
      format.html # confirm_delete.html.erb
    end
  end

  # DELETE /discussions/comments/1  
  def destroy
    raise ActiveRecord::RecordNotFound unless @comment.can_be_hidden_by?(current_member)
    if @comment.update_attributes( { :hidden => true, :last_edited_by_id => current_member.id })
      flash[:notice] = "This comment was removed."
    end

    respond_to do |format|
      format.html { redirect_to(discussions_comment_path(@comment.root)) }
      format.json do
        render :json => { :flash => flash }.to_json, :status => 200
        flash.discard
      end
    end
  end

  def undestroy
    raise ActiveRecord::RecordNotFound unless current_member.has_role_or_above?(:editor)
    if @comment.update_attributes( { :hidden => false, :last_edited_by_id => current_member.id })
      flash[:notice] = "This comment was restored."
    end

    respond_to do |format|
      format.json do 
        render :json => { :flash => flash }.to_json, :status => 200
        flash.discard
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = "Comment Not Found"
    respond_to do |format|
      format.html { redirect_to discussions_comments_path }
      format.json do
        render :json => { :flash => flash }.to_json, :status => 404
        flash.discard
      end
    end
  end

  protected
  def redirect_for(comment)
    case comment.commentable_type
    when "Source"
      @source = Source.find(comment.commentable_id)
      source_path(@source)
    when "Topic"
      @topic = Topic.find(comment.commentable_id)
      topic_path(@topic)
    when "Subject"
      @subject = Subject.find(comment.commentable_id)
      subject_path(@subject)
    when "Story"
      story_path(comment.commentable_id)
    else
      discussions_comment_path(comment)
    end
  end

  def find_comment
    @comment = Comment.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = "Comment Not Found"
    respond_to do |format|
      format.html { redirect_to discussions_comments_path }
      format.json do
        render :json => { :flash => flash }.to_json, :status => 404
        flash.discard
      end
    end
  end
end
