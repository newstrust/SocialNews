class Admin::Visualizations::MemberVizController < Admin::VisualizationsController
  include Admin::VisualizationsHelper

  private

  def get_member_keys
    params.keys.collect { |k| params[k] if k.to_s =~ /^m_\d+$/ }.compact.sort { |a,b| a.to_i <=> b.to_i }
  end

  public

  # ----------------------------------------
  # Rating distribution of reviews by member
  # ----------------------------------------
  def reviews_rating_distribution
    @member = Member.find(params[:member_id])
    query_string = "select format(review_summary.new_rating, 1), count(*) from review_summary, stories where review_summary.story_id = stories.id and review_summary.num_answers >= 3 and review_summary.member_id = #{@member.id} group by format(review_summary.new_rating, 1)"

    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, []) { |h, row| h[row[0].to_f] = row[1].to_i }
  end

  # -----------------------------------------------------------------------------------
  # Rating distribution of reviews by member - split by source-ownership and story-type
  # -----------------------------------------------------------------------------------
  def reviews_rating_distribution_by_story_type
    @member = Member.find(params[:member_id])
    query_string = "select format(review_summary.new_rating, 1), stories.stype_code, count(*) from review_summary, stories where review_summary.story_id = stories.id and review_summary.num_answers >= 3 and review_summary.member_id = #{@member.id} group by format(review_summary.new_rating, 1), stories.stype_code"

    plot_keys = [1,2,3,4] # the four stype_code keys in the db
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, plot_keys) { |h, row|
      h[row[1].to_i] ||= {}
      h[row[1].to_i][row[0].to_f] = row[2].to_i 
    }
  end

  # -----------------------------------------------------------------
  # Comparison of rating distribution of reviews for differnt members
  # -----------------------------------------------------------------
  def reviews_rating_distribution_comparison
    m_keys = get_member_keys
    @members = Member.find_all_by_id(m_keys)

    query_string = "select format(review_summary.new_rating, 1), review_summary.member_id, count(*) from review_summary, stories where review_summary.story_id = stories.id and review_summary.num_answers >= 3 and review_summary.member_id in (#{m_keys * ','}) group by format(review_summary.new_rating, 1), review_summary.member_id"

    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, m_keys) { |h, row|
      h[row[1]] ||= {}
      h[row[1]][row[0].to_f] = row[2].to_i 
    }
  end

  # ---------------------------------------------------------------------------------------
  # Rating distribution of stories submitted by member - by source-ownership and story-type
  # ---------------------------------------------------------------------------------------
  def submits_rating_distribution_by_story_type
    @member = Member.find(params[:member_id])
    query = "select format(stories.rating, 1), stories.stype_code, count(*) from stories where stories.submitted_by_id = #{@member.id} and stories.reviews_count >= 3 group by format(stories.rating, 1), stories.stype_code"

    plot_keys = [1,2,3,4]               # the four stype_code keys in the db
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, plot_keys) { |h, row|
      h[row[1].to_i] ||= {}
      h[row[1].to_i][row[0].to_f] = row[2].to_i 
    }
  end

  # -----------------------------------------------------------------------------
  # Bar chart of stories submitted by member - by source-ownership and story-type
  # -----------------------------------------------------------------------------
  def submits_by_story_type
    @member = Member.find(params[:member_id])

      # Fetch data from db
    db_rows = Member.connection.select_rows("select stories.stype_code, count(*) from stories where stories.submitted_by_id = #{@member.id} group by stories.stype_code")

      # Massage the data into a hash of x_val => y_val mappings
    stype_data = db_rows.inject({}) { |h,row| h[row[0].to_i] = row[1].to_i; h }

      # Generate flot data array
    @flot_data_array = get_plot_data_arrays((1..4), [], stype_data)
  end
end
