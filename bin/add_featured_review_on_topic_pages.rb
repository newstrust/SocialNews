def add_fr_block_to_site(ls = nil)
  eb = EditorialBlock.find_by_slug("featured_review")
  Topic.for_site(ls).find(:all).each { |t|
    begin
      es_attrs = { :local_site_id => ls ? ls.id : nil, :page_type => t.class.name, :page_id => t.id }
      es = EditorialSpace.find(:first,
                               :joins => "join editorial_block_assignments eba ON eba.editorial_space_id=editorial_spaces.id",
                               :conditions => es_attrs.merge("eba.editorial_block_id" => eb.id))
      if es
        puts "Topic #{t.id}:#{t.name} has featured review block already: ES: #{es.id}"
      else
        es = EditorialSpace.create(es_attrs.merge(:name => "Featured Reviewer", :show_name => 1, :context => "right_column", :position => 1))
        eba = EditorialBlockAssignment.create(:editorial_space_id => es.id, :editorial_block_id => eb.id)
        puts "Added ES: #{es.id}; EBA: #{eba.id} for topic #{t.id}:#{t.name}"
      end
    rescue Exception => e
      puts "Exception #{e} for topic #{t.id}:#{t.name}; BT: #{e.backtrace.inspect}"
    end
  }
end

add_fr_block_to_site; ""
