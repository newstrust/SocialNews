namespace :socialnews do
  desc "Generate source, topic, and feed taxonomies"
  # SSS FIXME: This always generates the national site taxonomy
  task(:gen_taxonomies => :environment) do
    ([nil] + LocalSite.find(:all)).each { |ls|
      ls_prefix = ls ? "#{ls.slug}." : ""
      File.open("#{RAILS_ROOT}/public/js/#{ls_prefix}topic_taxonomy.json", "w") { |f|
        topics = Topic.for_site(ls).find(:all,
                                         :select     => "id, name",
                                         :order      => "name ASC",
                                         :conditions => {:status => ["list", "feature"]}).map { |t| {:icon => t.image ? t.image.public_filename(:favicon): "/images/ui/topic_favicon.png", :name => t.name, :id => t.id } }
        f.write("var topic_taxonomy = #{topics.to_json};") 
      }
    }

    File.open("#{RAILS_ROOT}/public/js/mynews_topic_taxonomy.json", "w") { |f|
      ts = Topic.find(:all,
                      :select     => "id, name, type, slug",
                      :order      => "name ASC", 
                      :conditions => ["status in (?) AND local_site_id IS NULL AND id NOT IN (?)", ["list", "feature"], MynewsListing.mynews_special_subjects.map(&:id)])
      topics = ts.map { |t| {:icon => t.image ? t.image.public_filename(:favicon): "/images/ui/topic_favicon.png", :name => t.name, :id => t.id, :url => t.class == Topic ? "/topics/#{t.slug}" : "/#{t.slug}" } }
      f.write("var topic_taxonomy = #{topics.to_json};") 
    }

    File.open("#{RAILS_ROOT}/public/js/source_taxonomy.json", "w") { |f|
      sources = Source.find(:all,
                            :select     => "id, name, slug",
                            :order      => "name ASC",
                            :conditions => {:status => ["hide", "list", "feature"]}).map { |s| {:icon => !s.favicon.blank? ? s.favicon : "/images/ui/source_favicon.png", :name => s.name, :id => s.id, :url => "/sources/#{s.slug}" } }
      f.write("var source_taxonomy = #{sources.to_json};")
    }

    File.open("#{RAILS_ROOT}/public/js/feed_taxonomy.json", "w") { |f|
      feeds = Feed.find(:all,
                          :select     => "id, name, feed_type, subtitle",
                          :order      => "name ASC",
                          :conditions => Feed.regular_feeds_finder_condition).map { |s| {:icon => !s.favicon.blank? ? s.favicon : "/images/ui/feed_favicon.png", :name => (s.name || "") + (s.subtitle.blank? ? "" : " - " + s.subtitle), :id => s.id, :url => "/feeds/#{s.id}" } }
      f.write("var feed_taxonomy = #{feeds.to_json};")
    }
  end

  desc "Generate rating values <-> labels mapping"
  task(:gen_rating_to_label_mappings => :environment) do
    yaml_config = SocialNewsConfig["label_review_forms"]["review_labels"]
    h1 = {}
    h2 = {}
    yaml_config["quality"].each { |metric, labels| 
      h1[metric] = {:positive => labels["positive"].downcase, :negative => labels["negative"].downcase } 
      h2[labels["positive"].downcase] = { :rating => metric, :value => 5 }
      h2[labels["negative"].downcase] = { :rating => metric, :value => 1 }
    }
    yaml_config["popularity"].each { |metric, vals| h1[metric] = {:positive => "yes", :negative => "no"} }
    File.open("#{RAILS_ROOT}/public/js/ratings_labels_map.json", "w") { |f|
      f.write("var ratings_to_labels_map = #{h1.to_json};\n\n")
      f.write("var labels_to_ratings_map = #{h2.to_json};")
    }
  end
end
