module TopicsHelper
  def topic_photo_credit(topic)
    photo_credit(topic.image)
  end

  def topic_title_and_meta_info(topic, primary_subject)
    if primary_subject.to_s == "Politics"
      title = "Political News - " + topic.name
    elsif primary_subject.to_s == "Sci/Tech"
      title = "Science & Technology News - " + topic.name
    else
      title = primary_subject.to_s + " News - " + topic.name
    end
    meta_description = "News stories posted to #{SocialNewsConfig["app"]["name"]} on the topic of " + topic.name + "."
    meta_keywords =  title.gsub(" - ", ", ")

    [title, meta_keywords, meta_description]
  end

  def active_topics_for_subject(subject, local_site, max_topics)
    find_opts = { :conditions => "taggings_count >= 2", :order => "taggings_count DESC", :limit => max_topics } 
    if local_site
      find_opts[:joins] = " JOIN taggings t1 ON t1.tag_id = #{subject.tag.id} JOIN taggings t2 ON t2.taggable_id = t1.taggable_id AND t2.tag_id = #{local_site.constraint.id}"
    end
    subject.topics(find_opts)
  end

  def topic_taggings_count(topic, local_site)
    local_site.nil? ? "<span class='editorial_gray'>(#{number_format(topic.taggings_count)})</span>" : ""
  end
end
