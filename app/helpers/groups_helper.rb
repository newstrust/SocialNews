module GroupsHelper
  def landing_page_tabs(group, group_activities, group_activity_hash)
    tabs = SocialGroupAttributes::AVAILABLE_LISTINGS.collect do |l|
      tab_type = l[1].to_sym
      if group.has_listing?(tab_type)
        # Set up tab for rendering -- only the initial listing tab will be rendered
        tab = { :type => tab_type, :name => l[0], :switch_callback => SocialGroupAttributes::TAB_SWITCH_CALLBACKS[tab_type] }
        if tab_type == @init_listing_type 
          if @init_listing_type == :activity
            tab[:partial] = "shared/landing_pages/listings/activity"
            tab[:locals]  = {:group => group, :activities => group_activities, :activity_hash => group_activity_hash}
          elsif @init_listing_type == :new_stories
            tab[:partial] = "shared/landing_pages/listings/mynews"
            tab[:locals] = {}
          end
        end

        tab
      end
    end
    tabs.compact!

    if group.sg_attrs.default_listing
      # Resort tabs so that the first tab is the default one
      init_tab = group.sg_attrs.default_listing.to_sym
      ## SSS: Ruby 1.8 does not have stable sort, so am abandoning this code!
      ## tabs.sort! { |t1,t2| t1[:type] == init_tab ? -1 : (t2[:type] == init_tab ? 1 : 0) }
      [tabs.find { |t| t[:type] == init_tab }].compact + tabs.reject { |t| t[:type] == init_tab }
    else
      tabs
    end
  end
end
