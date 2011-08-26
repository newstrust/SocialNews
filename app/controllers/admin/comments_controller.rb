class Admin::CommentsController < Admin::AdminController
  before_filter :find_comment, :except => [:index, :deleted]
  layout 'admin'

  # GET /admin/comments/
  def index
    redirect_to deleted_admin_comments_path
  end

  # GET /admin/comments/deleted.html
  def deleted
    @comments = Comment.paginate(:all, pagination_params.merge(:conditions => ['hidden = ?',true]))
  end

  # GET /admin/comments/1/confirm_delete.html
  def confirm_delete
    flash[:notice] = "Are you sure you want to remove this comment?"
    respond_to do |format|
      format.html # confirm_delete.html.erb
    end
  end

  # DELETE /admin/comments/1.html
  def destroy
    if @comment.update_attributes( { :hidden => true, :last_edited_by_id => current_member.id })
      flash[:notice] = "This comment was removed"
    end

    respond_to do |format|
      format.html { redirect_to(admin_comment_path(@comment.root)) }
    end
  end

  # GET /admin/comments/1/undelete.html
  def undelete
    if @comment.update_attributes( { :hidden => false, :last_edited_by_id => current_member.id })
      flash[:notice] = "This comment was restored."
    end

    respond_to do |format|
      format.html do 
        if request.env["HTTP_REFERER"] =~ /[^admin]/
          redirect_to(request.env["HTTP_REFERER"]) 
        else
          redirect_to(admin_comment_path(@comment)) 
        end
      end
    end
  end

  protected 
  def find_comment
    @comment = Comment.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to admin_comments_path
  end
end
