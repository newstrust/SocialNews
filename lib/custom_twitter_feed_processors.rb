module CustomTwitterFeedProcessors
  # Muckrack has 2 types of tweets.  
  # 1. One in which there is only one link -- this refers to trending pages on muckrack
  # 2. One in which there are two link -- the first one refers to the muckrack page, the second one refers to the actual article!
  def self.muckrack_process_feed_entry(feed_entry)
    all_links = feed_entry.title.scan(%r|http://[^\s]*|)
    return (all_links.length == 1) ? nil : all_links[1]
  end
end
