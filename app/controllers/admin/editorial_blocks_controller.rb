class Admin::EditorialBlocksController < Admin::AdminController
  layout 'admin'

  include Admin::LandingPageHelper
  
  # GET /editorial_blocks/new
  # GET /editorial_blocks/new.xml
  def new
    @editorial_block = EditorialBlock.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @editorial_block }
    end
  end

  # GET /editorial_blocks/1/edit
  def edit
    @editorial_block = EditorialBlock.find(params[:id])
  end

  # POST /editorial_blocks
  # POST /editorial_blocks.xml
  def create
    @editorial_block = EditorialBlock.new(params[:editorial_block].merge(:context => 'right_column'))
    if @editorial_block.save
      EditorialBlockAssignment.create(params[:editorial_block_assignment]) if params[:editorial_block_assignment][:editorial_space_id]
      redirect_to page_layout_path
    else
      render :action => "new"
    end
  end

  # PUT /editorial_blocks/1
  # PUT /editorial_blocks/1.xml
  def update
    @editorial_block = EditorialBlock.find(params[:id])
    if @editorial_block.update_attributes(params[:editorial_block])
      if params[:editorial_block_assignment][:editorial_space_id]
        # Revoke the previous assignment
        eba = EditorialBlockAssignment.find_block_assignment(@local_site, @editorial_block.id, params[:page_type], params[:page_id])
        eba.destroy if eba
        # Create a new one!
        EditorialBlockAssignment.create(params[:editorial_block_assignment])
      end
      flash[:notice] = 'EditorialBlock was successfully updated.'
      redirect_to page_layout_path
    else
      render :action => "edit"
    end
  end

  # DELETE /editorial_blocks/1
  # DELETE /editorial_blocks/1.xml
  def destroy
    @editorial_block = EditorialBlock.find(params[:id])
    @editorial_block.destroy

    redirect_to page_layout_path
  end
  
  def preview
    @editorial_block = EditorialBlock.find(params[:id])
    render :layout => "popup"
  end

end
