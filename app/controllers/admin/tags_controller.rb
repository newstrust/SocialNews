class Admin::TagsController < Admin::AdminController
  layout 'admin'

  def add_mass_tags
    src_tag_name = params[:source_tag].strip.gsub(/\s+/, " ")
    tgt_tag_name = params[:target_tag].strip.gsub(/\s+/, " ")
    source_tag = Tag.find_by_name(src_tag_name)
    target_tag = Tag.find_by_name(tgt_tag_name)

		if (!source_tag)
			flash[:error] = "Source tag #{src_tag_name} does not exist!  Please remember to enter the *name* of the tag, not the *slug*!"
		else
				# Create the target tag if it doesn't exist
      notice = ""
			if (!target_tag)
        notice = "New Target Tag #{tgt_tag_name} created since it couldn't be found!  If you entered the *slug* of an existing tag, please retag with the correct tag name!<br/>"
				t = Tag.new(:name => tgt_tag_name)
				t.save!
			end

      # NOTE: We can do this entirely in ruby too -- but that can be db-intensive if the # stories to mass-tag are large!

				# Set up the sql statement
			start_date = params[:start_date]
			end_date   = params[:end_date]
			if (!start_date.blank? || !end_date.blank?)
				start_condition = " AND s.sort_date >= '#{start_date}'" if !start_date.blank?
				end_condition   = " AND s.sort_date <= '#{end_date}'" if !end_date.blank?
				sql_stmt = "INSERT INTO taggings(tag_id, taggable_id, member_id, taggable_type, context, created_at) (SELECT #{target_tag.id}, t2.taggable_id, #{current_member.id}, 'Story', t2.context, t2.created_at FROM taggings t2, stories s WHERE t2.taggable_id IS NOT NULL AND t2.tag_id = #{source_tag.id} AND t2.taggable_type = 'Story' AND t2.taggable_id NOT IN (SELECT taggable_id FROM taggings t3 WHERE t3.taggable_id IS NOT NULL AND t3.tag_id = #{target_tag.id} AND t3.taggable_type = 'Story') AND s.id = t2.taggable_id#{start_condition}#{end_condition})"
			else
				sql_stmt = "INSERT INTO taggings(tag_id, taggable_id, member_id, taggable_type, context, created_at) (SELECT #{target_tag.id}, t2.taggable_id, #{current_member.id}, 'Story', t2.context, t2.created_at FROM taggings t2 WHERE t2.taggable_id IS NOT NULL AND t2.tag_id = #{source_tag.id} AND t2.taggable_type = 'Story' AND t2.taggable_id NOT IN (SELECT taggable_id FROM taggings t3 WHERE t3.taggable_id IS NOT NULL AND t3.tag_id = #{target_tag.id} AND t3.taggable_type = 'Story'))"
			end

				# Run the update
			Tagging.connection.execute(sql_stmt)

        # Update taggings count!
			Tagging.connection.execute("UPDATE tags SET tags.taggings_count = (SELECT COUNT(*) FROM taggings WHERE taggings.taggable_id IS NOT NULL AND taggings.tag_id = tags.id) WHERE tags.id = #{target_tag.id}")

      flash[:notice] = notice + "Added tags successfully!"
		end

    redirect_to admin_tags_url
  end
end
