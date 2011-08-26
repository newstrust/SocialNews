class SourceReviewsController < ApplicationController
  before_filter :find_review, :except => [:create]
  before_filter :login_required

  include ApplicationHelper

  def edit
  end

  def show
  end

  def new
    render_404 and return
  end

  def create
    tag_attrs = params[:source_review].delete(:expertise_attrs)
    params[:source_review][:expertise_topic_ids] = (tag_attrs ? tag_attrs.collect { |ta| ta["id"] if ta["should_destroy"] != "true" }.compact : []) * ","
    @source_review = SourceReview.new(params[:source_review])
    @source_review.local_site = @local_site

    respond_to do |format|
      if @source_review.save_and_process_with_propagation
        format.html { redirect_to source_path(@source_review.source) }
        format.js   { render :json => {:source_id => @source_review.source.id, :rating => @source_review.rating} }
      else
        errs = @source_review.errors.full_messages
        logger.error "Errors saving #{@source_review.inspect}: #{errs.inspect}"
        format.html { render :action => 'edit' }
        format.js   { render :json => {:error_message => "Error saving your review. #{errs.join('<br/>')}" } }
      end
    end
  end

  # PUT /source-reviews/id.html
  def update
    is_admin = current_member.has_role_or_above?(:admin)
    if !is_admin
      # No manipulating status OR another member's review unless you are an admin!
      params[:source_review][:status] = nil 
      if @source_review.member != current_member
        flash[:error] = "You cannot modify another member's review"
        redirect_to(source_path(@source_review.source)) 
        return 
      end
    else
      if @source_review.member != current_member
        # No manipulating anything except the status itself!
        params[:source_review] = { :status => params[:source_review][:status] }
      end
    end

    # Convert expertise tag attrs to a form that we store in the db
    tag_attrs = params[:source_review].delete(:expertise_attrs)
    params[:source_review][:expertise_topic_ids] = tag_attrs.collect { |ta| ta["id"] if ta["should_destroy"] != "true" }.compact * "," if tag_attrs

    # Only update attributes that are included in params
    @source_review.attributes = params[:source_review]
    if @source_review.save_and_process_with_propagation
      # Send a notification to editors
      if @source_review.hidden? && !is_admin
        NotificationMailer.deliver_edit_alert(:subject => "Hidden Source Review Updated", :body => "Check #{source_review_url(@source_review)}.\n\nReview:#{@source_review.note}")
      end
      respond_to do |format|
        format.html { flash[:notice] = "Source Review Updated"; redirect_to(source_path(@source_review.source)) }
        format.js   { render :json => {:source_id => @source_review.source.id, :rating => @source_review.rating} }
      end
    else
      respond_to do |format|
        errs = @source_review.errors.full_messages
        logger.error "Errors saving #{@source_review.inspect}: #{errs.inspect}"
        format.html { render :template => 'source_reviews/edit' }
        format.js   { render :json => {:error_message => "Error saving your review. #{errs.join('<br/>')}" } }
      end
    end
  end

  protected

  def find_review
    @source_review = SourceReview.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to home_path
  end
end
