module SubjectExtension
  def add(subject, grouping = nil)
    # We do find and initialize here instead of create so that we can support updating records
    # and not just adding them.
    @topic_relation = @owner.topic_relations.find_or_initialize_by_related_topic_id_and_context(:context => 'subject', :related_topic_id => subject.id)
    @topic_relation.grouping = grouping if grouping
    @topic_relation.local_site_id = @owner.local_site_id
    @topic_relation.save
    
    @owner.subjects(true)
  end
  
  def remove(subject)
    @topic_relation = @owner.topic_relations.find_by_related_topic_id(subject.id)
    raise ActiveRecord::RecordNotFound unless @topic_relation
    @topic_relation.destroy
    @owner.subjects(true)
  end
  
  # Adds and/or deletes subjects based on the hash sent in.
  def update(params)
    @groupings = {}
    
    # Delete the grouping key if one exists.
    if params.has_key?("grouping")
      @groupings = params.fetch("grouping")
      params.delete("grouping")
    end
    
    @to_add = params.map.reject{ |x| x[1].to_i == 0 }.map{|x|x[0]}
    
    # Add the groupings to the keys if any were supplied.
    @to_add = @to_add.collect { |x| [x,@groupings.key?(x) ? @groupings[x] : nil] }
    
    # only add this record if it doesn't already exit
    @to_add.each do |arr|
      # next if names.include?(arr[0])
      @subject = Subject.find_subject(arr[0], @owner.local_site)
      add(@subject, arr[1])
    end
    
    @to_remove = params.map.reject{ |x| x[1].to_i == 1 }.map{|x|x[0]}
    
    @to_remove.each do |name|
      next unless names.include?(name)
      @subject = Subject.find_subject(name, @owner.local_site)
      remove(@subject)
    end
  end
  
  protected
  def names
    @owner.subjects.map{ |x| x.slug.downcase }
  end
end
