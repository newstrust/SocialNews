class Admin::LandingPageController < Admin::AdminController
  include Admin::LandingPageHelper

  # All landing pages have the default contexts below
  # But homepage (national and local sites don't conform -- need to fix this!)
  def load_landing_page_layout_settings(obj, contexts = ["featured_story", "news_comparison", "grid", "right_column"])
    local_site = use_site_specific_layout?(obj.class.name) ? @local_site : nil
    @settings = {}
    contexts.each { |ctxt| @settings[ctxt] = LayoutSetting.load_settings(local_site, obj, ctxt) }

      # Story properties in the story grid, and the topic listing property in the news_comparison area are stored as a hash.  Unmarshal them!
    @settings["grid"].each { |c| if c && c.name =~ /c\d/; c.unmarshal!; c.value["lt_slug"] ||= ""; end }
    @settings["news_comparison"].find {|s| s && (s.name == "topic_listing") }.unmarshal!

    @editorial_spaces = EditorialSpace.on_landing_page(local_site, obj).find(:all, :conditions => {:context => "right_column"}, :order => "position ASC")
    @editorial_blocks = EditorialBlock.find(:all, :conditions => ["slug NOT in (?)", EditorialBlock::PRE_BAKED_BLOCK_SLUGS], :order => 'slug ASC')
    @predefined_blocks = EditorialBlock.find(:all, :conditions => ["slug in (?)", EditorialBlock::PRE_BAKED_BLOCK_SLUGS], :order => 'slug ASC')
  end

  def update_landing_page_layout(obj)
    local_site = use_site_specific_layout?(obj.class.name) ? @local_site : nil
    validate_landing_page_layout_params(local_site, obj)

    page_type = obj ? obj.class.name : nil
    page_id   = obj ? obj.id : nil

      # Update only if there are no errors!
    if flash[:error].blank?
      sc = params[:settings]
      sc.keys.each { |ctxt|
        sc[ctxt].each { |name, attrs|
            # For the carousel, very story in the story grid area and for the topic listing property in the
            # news comparison area, all attributes are collected into a hash, marshalled, and dumped into the db
          field_order = attrs.delete(:field_order)
          (ctxt == "grid" && name =~ /c\d/) || (ctxt == "news_comparison" && name == "topic_listing") || (ctxt == "carousel") ? LayoutSetting.marshal_hash(attrs) : attrs[:value].strip!
          ls = LayoutSetting.find(:first, :conditions => {:page_id => page_id, :page_type => page_type, :local_site_id => local_site ? local_site.id : nil, :context => ctxt, :name => name})
          if ls
            attrs.merge!(:last_edited_by_member => current_member)
            ls.update_attributes(attrs)
          else
            attrs.merge!(:last_edited_by_member => current_member, :name => name, :local_site_id => local_site ? local_site.id : nil, :page_type => page_type, :page_id => page_id, :context => ctxt, :field_order => field_order)
            LayoutSetting.create(attrs)
          end
        }
      }

      # Set up NC stories as related to each other
      nc_sc = sc[:news_comparison]
      if (nc_sc[:use_topic_listing?][:value].to_i == 0) && (nc_sc[:link_stories?][:value].to_i == 1)
        nc_stories = (1..3).collect { |i| sid = nc_sc["story_#{i}"][:value]; Story.find(sid) if !sid.blank? }.compact
        nc_stories.each { |x| 
          nc_stories.each { |y| 
            # No dupe story relations, please!
            if (x != y) && (!x.related_stories.to_ary.find { |rs| rs.id == y.id })
              x.story_relations << StoryRelation.new(:related_story => y, :member => current_member) 
            end
          }
        }
      end
      flash[:notice] = "Updated layout successfully!<br/>" + (flash[:notice] || "")
    else
      flash[:error] = "Your values have not been saved!<br/>Please GO BACK TO THE PREVIOUS SCREEN and correct the following errors. <br/><br/>" + flash[:error]
    end
  end

  def clone_editorial_spaces
    page_type    = params[:page_type]
    page_id      = params[:page_id]
    from_site_id = params[:from_site]
    to_site_id   = params[:to_site]
    if !(from_site_id && to_site_id)
      flash[:error] = "Bad parameters: from_site_id=#{from_site_id}, to_site_id=#{to_site_id}; Both these params should be non-nil."
      redirect_to page_layout_path(:page_id => page_id, :page_type => page_type) && return
    end

    to_site_id   = nil if to_site_id == "0"
    from_site_id = nil if from_site_id == "0"
    if EditorialSpace.exists?(:local_site_id => to_site_id, :page_type => page_type, :page_id => page_id)
      to_site = to_site_id ? LocalSite.find(to_site_id) : nil
      flash[:error] = "#{page_type} #{page_id} has existing editorial spaces on the #{to_site ? to_site.name : 'National'} site.  Cloning request ignored."
    else
      from_site = from_site_id ? LocalSite.find(from_site_id) : nil
      to_site = to_site_id ? LocalSite.find(to_site_id) : nil
      flash[:notice] = "Cloned all editorial spaces from #{from_site ? from_site.name : 'National'} site to #{to_site ? to_site.name : 'National'} site"
      from_es = EditorialSpace.find(:all, :conditions => {:local_site_id => from_site_id, :page_type => page_type, :page_id => page_id})
      from_es.each { |es|
        t = Time.now
        es_cl = EditorialSpace.create(es.attributes.merge!(:local_site_id => to_site_id, :created_at => t, :updated_at => t))
        es.editorial_block_assignments.each { |b| EditorialBlockAssignment.create(b.attributes.merge!(:editorial_space_id => es_cl.id, :created_at => t, :updated_at => t)) }
      }
    end
    redirect_to page_layout_path(:page_id => page_id, :page_type => page_type)
  end
end
