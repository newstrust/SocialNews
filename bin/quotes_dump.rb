module QuotesDump
  #rand_ids = (1..50000).to_a.shuffle
  quotes = Quote.find(:all, :conditions => ["quotes.status IN ('list', 'feature')"])
  data = quotes.collect { |q|
    puts "Processing quote: #{q.id}"
	 # base quote attrs
	 q_attrs = q.attributes.reject { |k,v| !["quote", "author", "about", "created_at", "story_id", "headline"].include?(k) }
	 #q_attrs["poster_id"] = rand_ids[q.poster_id]
	 q_attrs["poster_id"] = q.poster_id

	 # answers
	 q_answer_attrs = q.answers.collect { |qa| 
	   answer_attrs = qa.attributes.reject { |k,v| !["note", "created_at"].include?(k) } 
		# additional attrs
		#answer_attrs["member_id"] = rand_ids[qa.member_id]
		answer_attrs["member_id"] = qa.member_id
		answer_attrs["answer_type"] = case qa.answer_type
		  when nil then "no-answer"
		  when -1  then "false"
		  when 0   then "not sure"
		  when 1   then "true"
		end
		answer_attrs
    }

	 q_link_attrs = q.links.reject { |ql| !ql.curated }.collect { |ql| 
	  link_attrs = ql.attributes.reject { |k,v| !["url", "link_type", "story_id", "created_at"].include?(k) }
		#link_attrs["submitter_id"] = rand_ids[ql.submitter_id]
		link_attrs["submitter_id"] = ql.submitter_id
		s = ql.story
		link_attrs["title"] = s.title
		link_attrs["publication"] = s.primary_source ? s.primary_source.name : "--pending source--"
		link_attrs["rating"] = s.rating
		link_attrs["reviews_count"] = s.reviews_count
		link_attrs
  	 }
	 {:claim => q_attrs, :links => q_link_attrs, :quote_answers => q_answer_attrs}
  }
  File.open("/tmp/quotes.xml", "w") { |f| f.write(data.to_xml) }
end
