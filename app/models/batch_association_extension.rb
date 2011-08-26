# ActiveRecord::Associations extension thinger
#
# Use this extension with has_many associations if you need them to be CRUDdy & updatable
# from dynamic forms which add/remove objects using JS.
#
# roughly based on http://railscasts.com/episodes/75-complex-forms-part-3
#

module BatchAssociationExtension
  # Takes an array of attributes and updates the association collection accordingly:
  # UPDATE associations with IDs, ADD ones without, DELETE ones marked 'should_destroy'
  # All changes appear to be saved immediately, regardless of parent record
  def attributes_collection=(attributes_collection)
    attributes_collection.each do |aa|
      should_destroy = false
      should_destroy = eval(aa.delete("should_destroy")) if aa["should_destroy"]
      if aa[:id].blank?
        # ADD new association, to be saved when parent is saved.
        # we pass attributes through update_attributes in case class has overwritten that...?!
        build(aa) unless should_destroy
      else
        # detect is maybe faster than find but maybe less reliable--?!
        begin
          existing_association = find(aa[:id].to_i) #detect{|a| a.id == aa[:id].to_i}
          if !should_destroy
            existing_association.update_attributes(aa) # UPDATE existing association. must save here!
          else
            delete(existing_association) # SSS: call delete so that association callback is invoked!
            existing_association.destroy
          end
        rescue ActiveRecord::RecordNotFound
          # Record is not there even though we have an ID for it! Something has gotten out of whack.
          # In all likelihood, we accidentally set up some half-baked data because of a partially-processed
          # form. Let's just set it up again.
          build(aa) unless should_destroy
        end
      end
    end
    return self
  end
end
