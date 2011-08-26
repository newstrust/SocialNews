module Admin::LayoutHelper
  def listing_type_selector(scope, lval, add_picks=false)
    ltypes = [["Recent", "most_recent"], ["Trusted", "most_trusted"], ["Worst", "least_trusted"], ["Reviews", "recent_reviews"], ["Trusted Reviews", "trusted_reviews"]]
    ltypes << ["Picks", "member_picks"] if add_picks
    select_tag("#{scope}[listing_type]", options_for_select(ltypes, lval["listing_type"])) +
    select_tag("#{scope}[story_type]", options_for_select([["All", ""], ["News", "news"], ["Opinion", "opinion"]], lval["story_type"])) +
    select_tag("#{scope}[source_ownership]", options_for_select([["Both", ""], ["Mainstream", "msm"], ["Independent", "ind"]], lval["source_ownership"]))
  end

  # SSS FIXME: Rewrite this
  def title_selector(scope, opts, lval)
    select_tag("#{scope}[value]", options_for_select(opts.collect { |l| [l, l.split(" ").map(&:capitalize) * "_" ]}, lval))
  end

  protected

  def record_notice(area, e)
    flash[:notice] ||= ""
    flash[:notice] += area.upcase + ": " + e + "<br/>"
  end

  def record_error(area, e)
    flash[:error] ||= ""
    flash[:error] += area.upcase + ": " + e + "<br/>"
  end

  def verify_valid_model_id(model, nil_not_okay, area, args, key, val=args[key] ? args[key][:value] : "")
    x = val.strip
    if x.blank? && nil_not_okay
      record_error(area, "NULL #{model.to_s.downcase} id for #{key}")
    elsif !x.blank?
      o = model.find(x.to_i)
      if (o.class == Story) && !o.is_public?
        record_notice(area, "#{model.to_s.downcase} (ID: '#{x}') was not public.  Listed it automatically.")
        o.update_attribute(:status, Story::LIST)
      end
    end
  rescue
    record_error(area, "Invalid #{model.to_s.downcase} id '#{x}' for #{key}")
  end

  def verify_valid_model_slug(model, nil_not_okay, area, args, key, find_opts=nil, val=args[key] ? args[key][:value] : "")
    x = val.strip
    if (x.blank? && nil_not_okay) || (!x.blank? && model.find_by_slug(x, find_opts).nil?)
      record_error(area, "Invalid #{model.to_s.downcase} slug '#{x}' for #{key}")
    end
  rescue
    record_error(area, "Invalid #{model.to_s.downcase} slug '#{x}' for #{key}")
  end

  def validate_staging_params(local_site, is_homepage, args)
    if is_homepage
      verify_valid_model_slug(Topic, true, "staging", args, "featured_topic", {:conditions => {:local_site_id => local_site ? local_site.id : nil}})
    end

    verify_valid_model_id(Review, false, "staging", args, "review_1")
    verify_valid_model_id(Review, false, "staging", args, "review_2")
    verify_valid_model_slug(EditorialBlock, false, "staging", args, "block_1")
    verify_valid_model_slug(EditorialBlock, false, "staging", args, "block_2")
  end

  def validate_news_comparison_params(local_site, is_homepage, args)
    show_nc = (args["show_news_comparison?"] || args["show_box?"])[:value].to_i
    return if (show_nc == 0) # nothing to validate if we are hiding the news comparison area

    listing_cb = args["use_topic_listing?"][:value]
    if listing_cb.blank? || (listing_cb.strip.to_i == 0)
      verify_valid_model_id(Story,  true, "news_comparison", args, "story_1") # We need at least one story id!
      verify_valid_model_id(Story,  false, "news_comparison", args, "story_2")
      verify_valid_model_id(Story,  false, "news_comparison", args, "story_3")
    end
  end

  def validate_grid_params(local_site, is_homepage, args)
    (1..6).each { |i| 
      c_args = args["c#{i}"]
      verify_valid_model_id(Story,  false, "grid", args, "c#{i}", c_args["story"])
      if (c_args["listing"]["listing_type"] == "member_picks")
        verify_valid_model_slug(Member,  true, "grid", args, "Story #{i}", nil, c_args["lt_slug"])
      else
        x = c_args["lt_slug"].strip
        if !x.blank?
          t = Topic.find_topic(x, local_site)
          record_error("news comparison", "Invalid topic/subject slug '#{x}' for Story #{i}") if t.nil?
        end
      end
    }
  end

  def validate_carousel_params(local_site, is_homepage, args)
    args.keys.each { |name| 
      slide_args = args[name]
      if slide_args["active?"] 
        case slide_args["type"]
          when "story" then 
            verify_valid_model_id(Story, true, "carousel", nil, name, slide_args["story"]["story_id"])
            verify_valid_model_slug(Topic, true, "carousel", nil, name, {:conditions => {:local_site_id => local_site ? local_site.id : nil}}, slide_args["story"]["topic"])
          when "quote" then 
            verify_valid_model_id(Quote, true, "carousel", nil, name, slide_args["quote"]["quote_id"])
        end
      end
    }
  end

  def validate_right_column_params(local_site, f, args)
  end

  def validate_featured_story_params(local_site, is_homepage, args)
    if is_homepage || (args["show_box?"][:value].to_i == 1)
      verify_valid_model_id(Story,  true, "featured_story", args, "story")
      verify_valid_model_id(Review, false, "featured_story", args, "review_1")
      verify_valid_model_id(Review, false, "featured_story", args, "review_2")
      verify_valid_model_slug(EditorialBlock, false, "featured_story", args, "block_1")
      verify_valid_model_slug(EditorialBlock, false, "featured_story", args, "block_2")
    end
  end

  def validate_landing_page_layout_params(local_site, lp_obj)
    sc = params[:settings]
    sc.keys.collect { |ctxt| send("validate_#{ctxt}_params", local_site, !lp_obj || lp_obj.is_a?(LocalSite), sc[ctxt]) }.all?
  end
end
