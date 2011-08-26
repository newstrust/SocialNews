class FlagsController < ApplicationController
  before_filter :login_required

  # collection methods

  def create
    flag = current_member.flags.create(:flaggable_id => params[:flaggable_id], :flaggable_type => params[:flaggable_type], :reason => params[:reason])
    flash[:notice] = if flag.new_record?
      case flag.reason
      when 'flag'
        "You already flagged this #{flag.flaggable_type.downcase}"
      when 'like'
        "You already like this #{flag.flaggable_type.downcase}"
      end
    else # success
      case flag.reason
      when 'flag'
        "You flagged this #{flag.flaggable_type.downcase}"
      when 'like'
        "You like this #{flag.flaggable_type.downcase}"
      end

    end

    respond_to do |format|# note: you'll need to ensure that this route exists
      format.html { redirect_to flag.flaggable }
      format.json do
        render :json => { :id => flag.flaggable_id, :reason => flag.reason, :flaggable => flag.flaggable.for_json, :flaggable_type => flag.flaggable_type, :flash => flash }.to_json
        flash.discard
      end
    end
  end

  def destroy
    if current_member.has_role?('admin')

      # We need to find the flag in both contexts because it can be used from the #index action or a comment partial.
      @flag = Flag.find(:first, :conditions => { :flaggable_id => params[:id], :flaggable_type => params[:flaggable_type], :reason => params[:reason] })
      @flag = Flag.find(params[:id]) unless @flag
    else
      @flag = current_member.flags.find(:first, :conditions => { :flaggable_id => params[:id], :flaggable_type => params[:flaggable_type], :reason => params[:reason] })
    end
    raise ActiveRecord::RecordNotFound unless @flag
    if @flag.destroy
      flash[:notice] = case @flag.reason
      when 'flag'
        "You unflagged this #{@flag.flaggable_type.downcase}"
      when 'like'
        "You unliked this #{@flag.flaggable_type.downcase}"
      end
    end

    respond_to do |format|
      format.html { redirect_to(flags_url) }
      format.json do
        render :json => { :reason => @flag.reason, :flaggable => @flag.flaggable.for_json, :flaggable_type => @flag.flaggable_type, :id => @flag.flaggable_id, :flash => flash }.to_json
        flash.discard
      end
    end
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Flag could not be found"
    respond_to do |format|
      format.html {redirect_to(flags_url)}
      format.json do
        render :json => { :id => params[:id], :flash => flash }.to_json
        flash.discard
      end
    end
  end
end