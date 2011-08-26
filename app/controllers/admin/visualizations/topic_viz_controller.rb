class Admin::Visualizations::TopicVizController < Admin::VisualizationsController
  include Admin::VisualizationsHelper

  private

  def get_tag_keys
    params.keys.collect { |k| params[k] if k.to_s =~ /^tag_\d+$/ }.compact.sort
  end

  public

  # --------------------------------------------------------
  # Rating distribution of reviews (with at least 3 answers)
  # --------------------------------------------------------
  def reviews_rating_distribution
    @tag = Topic.find_topic(params[:tag_id])
    query_string = "select format(review_summary.new_rating, 1), count(*) from review_summary, stories, taggings where review_summary.story_id = stories.id and review_summary.num_answers >= 3 and taggings.taggable_id = stories.id and taggings.taggable_type = 'Story' and taggings.tag_id = #{@tag.id} group by format(review_summary.new_rating, 1)"
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, []) { |h, row| h[row[0].to_f] = row[1].to_i }
  end

  # --------------------------------------------------------
  # Rating distribution of stories (with at least 3 reviews)
  # --------------------------------------------------------
  def stories_rating_distribution
    @tag = Topic.find_topic(params[:tag_id])
    query_string = "select format(stories.rating, 1), count(*) from stories, taggings where stories.reviews_count >= #{SocialNewsConfig["min_reviews_for_story_rating"]} and taggings.taggable_id = stories.id and taggings.taggable_type='Story' and taggings.tag_id = #{@tag.id} group by format(stories.rating, 1)"
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, []) { |h, row| h[row[0].to_f] = row[1].to_i }

    render :template => 'admin/visualizations/topic_viz/reviews_rating_distribution'
  end

  # ---------------------------------------------------------------------------
  # Source Comparison of rating distribution for reviews with 3 or more answers
  # ---------------------------------------------------------------------------
  def reviews_rating_distribution_comparison
      # Find tag_keys
    slugs = get_tag_keys
    @tags = Tag.find_all_by_slug(slugs, :order => "tags.slug")

      # query string for fetching data from db
    query_string = "select format(review_summary.new_rating, 1), tags.slug, count(*) from review_summary, stories, taggings, tags where review_summary.story_id = stories.id and review_summary.num_answers >= 3 and taggings.taggable_id = stories.id and tagging.taggable_type = 'Story' and taggings.tag_id = tags.id and tags.slug in (#{slugs * ','}) group by format(review_summary.new_rating, 1), tags.slug"

      # process data -- while passing a block that processes a db row
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, slugs) { |h, row|
      h[row[1]] ||= {} 
      h[row[1]][row[0].to_f] = row[2].to_i 
     }
  end

  # ---------------------------------------------------------------------------
  # Source Comparison of rating distribution for stories with 3 or more reviews
  # ---------------------------------------------------------------------------
  def stories_rating_distribution_comparison
      # Find src_keys
    slugs = get_tag_keys
    @tags = Tag.find_all_by_slug(slugs, :order => "tags.slug")

      # query string for fetching data from db
    query_string = "select format(stories.rating, 1), tags.slug, count(*) from stories, taggings, tags where taggings.taggable_id = stories.id and taggings.taggable_type = 'Story' and taggings.tag_id = tags.id and tags.slug in (#{slugs.collect {|t| "\'" + t + "\'"} * ','}) and stories.reviews_count >= #{SocialNewsConfig["min_reviews_for_story_rating"]} group by format(stories.rating, 1), tags.slug"

      # process data -- while passing a block that processes a db row
    @flot_data_array = fetch_data_and_generate_plot_data_arrays(query_string, slugs) { |h, row|
      h[row[1]] ||= {} 
      h[row[1]][row[0].to_f] = row[2].to_i 
    }

    render :template => 'admin/visualizations/topic_viz/reviews_rating_distribution_comparison'
  end

  # -------------------------------------------------
  # Timeseries data for # of submits and # of reviews
  # -------------------------------------------------
  def submit_and_review_timeseries
    @tag = Topic.find_topic(params[:tag_id])
    query_string = "select count(*) as n, stories.sort_date as d from taggings, stories where taggings.taggable_type = 'Story' and taggings.tag_id = #{@tag.id} AND taggings.taggable_id = stories.id and sort_date >= '2008-10-01' and (stories.status = 'list' or stories.status = 'feature') group by stories.sort_date"
    db_rows = ActiveRecord::Base.connection.select_rows(query_string)

    data = {}

      # Massage the data into a hash of x_val => y_val mappings
      # But, yield to the caller to process the db row
    data["submits"] = db_rows.inject({}) { |h,row| 
      d = Time.parse(row[1]).to_i*1000  # convert date to an unix timestamp, but in milliseconds
      h[d.to_s] = row[0].to_i
      h
    }

    query_string = "select count(*) as n, date(reviews.created_at) as d from taggings, stories, reviews where taggings.taggable_type = 'Story' and taggings.tag_id = #{@tag.id} AND taggings.taggable_id = stories.id and stories.sort_date >= '2008-10-01' and reviews.story_id=stories.id and (stories.status = 'list' or stories.status = 'feature') and (reviews.status = 'list' or reviews.status = 'feature') group by date(reviews.created_at)"
    db_rows = ActiveRecord::Base.connection.select_rows(query_string)

      # Massage the data into a hash of x_val => y_val mappings
      # But, yield to the caller to process the db row
    data["reviews"] = db_rows.inject({}) { |h,row| 
      d = Time.parse(row[1]).to_i*1000  # convert date to an unix timestamp, but in milliseconds
      h[d.to_s] = row[0].to_i
      h
    }

      # X-axis: time-series
    xs = data.values.collect { |k| k.keys }.flatten.uniq.sort

    @plot_keys = data.keys.uniq.sort

      # Generate flot data array
    @flot_data_array = get_plot_data_arrays(xs, @plot_keys, data)
  end

  def story_submit_timeseries
#    query_string = "select count(*) as n, stories.sort_date as d, tags.name as subject from taggings, tags, stories where taggings.taggable_type = 'Story' and taggings.tag_id = tags.id and tags.tag_type = 'Subject' and taggings.taggable_id = stories.id and sort_date >= '2009-01-01' group by tags.id, stories.sort_date"
    query_string = "select count(*) as n, stories.sort_date as d, tags.name as subject from taggings, tags, stories where taggings.taggable_type = 'Story' and taggings.tag_id = tags.id and taggings.taggable_id = stories.id and sort_date >= '2008-10-01' and reviews_count >= 3 and tags.name in ('Gaza', 'Obama Administration', 'Global Warming', 'Money', 'John McCain', 'Presidential Election 2008') group by tags.id, stories.sort_date"
#    query_string = "select count(*) as n, stories.sort_date as d, round(2*stories.rating) as rating from stories where sort_date >= '2008-10-01' and sort_date <= '2009-02-10' and reviews_count >= 3 group by stories.sort_date, round(2*stories.rating)"

      # Fetch data from the db!
    db_rows = ActiveRecord::Base.connection.select_rows(query_string)

      # Massage the data into a hash of x_val => y_val mappings
      # But, yield to the caller to process the db row
    data = db_rows.inject({}) { |h,row| 
      h[row[2]] ||= {}
      d = Time.parse(row[1]).to_i*1000  # convert date to an unix timestamp, but in milliseconds
      h[row[2]][d.to_s] = row[0].to_i;
      h
    }

      # X-axis: time-series
    xs = data.values.collect {|h| h.keys }.flatten.uniq.sort

      # Subject plot keys
    @plot_keys = data.keys.uniq.sort

      # Generate flot data array
    @flot_data_array = get_plot_data_arrays(xs, @plot_keys, data, {:x_aggregate => false, :y_aggregate => true, :normalize => true, :normalize_type => "equal-y-sums"})
  end
end
