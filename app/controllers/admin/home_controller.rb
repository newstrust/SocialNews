class Admin::HomeController < Admin::LandingPageController
  include Admin::LayoutHelper

  layout 'admin'
  grant_access_to :editor
  
  def index
    edit
    render :action => 'edit'
  end

  def edit
    load_landing_page_layout_settings(nil, ["carousel", "staging", "news_comparison", "grid"])
    @carousel_slides = {}
    (1..SocialNewsConfig["num_carousel_slides"]).each { |i| @carousel_slides["slide#{('A'[0]+i-1).chr}"] = {} }
    (@settings["carousel"] || {}).each { |slide| 
      slide.unmarshal!
      # To deal with all the code changes and make sure existing db settings on dev & staging dont break
      slide.name.gsub!(/slot(\d)/) { |m| "slide#{('A'[0]+$1.to_i-1).chr}"}
      @carousel_slides[slide.name] = slide.value 
    }
  end

  def update
    update_landing_page_layout(nil)
    if flash[:error]
      load_landing_page_layout_settings(nil, ["carousel", "staging", "news_comparison", "grid"])
      @carousel_slides = {}
      (1..SocialNewsConfig["num_carousel_slides"]).each { |i| @carousel_slides["slide#{('A'[0]+i-1).chr}"] = {} }
      (@settings["carousel"] || {}).each { |slide| slide.unmarshal!; @carousel_slides[slide.name] = slide.value }
      flash.discard
      render :action => :edit
    else
      redirect_to @local_site ? @local_site.home_page : home_url
    end
  end

  def preview
  end
end
