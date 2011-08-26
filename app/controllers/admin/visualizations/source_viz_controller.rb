class Admin::Visualizations::SourceVizController < Admin::VisualizationsController
  include Admin::VisualizationsHelper

  private

  def get_src_keys
    params.keys.collect { |k| params[k] if k.to_s =~ /^src_\d+$/ }.compact.sort { |a,b| a.to_i <=> b.to_i }
  end

  public

  # --------------------------------------------------------
  # Rating distribution of reviews (with at least 3 answers)
  # --------------------------------------------------------
  def reviews_rating_distribution
    @source = Source.find(params[:source_id])
    query_string = "select format(review_summary.new_rating, 1), count(*) from review_summary, stories, authorships where review_summary.story_id = stories.id and review_summary.num_answers >= 3 and authorships.story_id = stories.id and authorships.source_id = #{@source.id} group by format(review_summary.new_rating, 1)"
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, []) { |h, row| h[row[0].to_f] = row[1].to_i }
  end

  # --------------------------------------------------------
  # Rating distribution of stories (with at least 3 reviews)
  # --------------------------------------------------------
  def stories_rating_distribution
    @source = Source.find(params[:source_id])
    query_string = "select format(stories.rating, 1), count(*) from stories, authorships where stories.reviews_count >= #{SocialNewsConfig["min_reviews_for_story_rating"]} and authorships.story_id = stories.id and authorships.source_id = #{@source.id} group by format(stories.rating, 1)"
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, []) { |h, row| h[row[0].to_f] = row[1].to_i }

    render :template => 'admin/visualizations/source_viz/reviews_rating_distribution'
  end

  # ---------------------------------------------------------------------------
  # Source Comparison of rating distribution for reviews with 3 or more answers
  # ---------------------------------------------------------------------------
  def reviews_rating_distribution_comparison
      # Find src_keys
    src_keys = get_src_keys
    @sources = Source.find(src_keys)

      # query string for fetching data from db
    query_string = "select format(review_summary.new_rating, 1), authorships.source_id, count(*) from review_summary, stories, authorships where review_summary.story_id = stories.id and review_summary.num_answers >= 3 and authorships.story_id = stories.id and authorships.source_id in (#{src_keys * ','}) group by format(review_summary.new_rating, 1), authorships.source_id"

      # process data -- while passing a block that processes a db row
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, src_keys) { |h, row|
      h[row[1]] ||= {} 
      h[row[1]][row[0].to_f] = row[2].to_i 
     }
  end

  # ---------------------------------------------------------------------------
  # Source Comparison of rating distribution for stories with 3 or more reviews
  # ---------------------------------------------------------------------------
  def stories_rating_distribution_comparison
      # Find src_keys
    src_keys = get_src_keys
    @sources = Source.find(src_keys)

      # query string for fetching data from db
    query_string = "select format(stories.rating, 1), authorships.source_id, count(*) from stories, authorships where authorships.story_id = stories.id and authorships.source_id in (#{src_keys * ','}) and stories.reviews_count >= #{SocialNewsConfig["min_reviews_for_story_rating"]} group by format(stories.rating, 1), authorships.source_id"

      # process data -- while passing a block that processes a db row
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, src_keys) { |h, row|
      h[row[1]] ||= {} 
      h[row[1]][row[0].to_f] = row[2].to_i 
    }

    render :template => 'admin/visualizations/source_viz/reviews_rating_distribution_comparison'
  end
end
