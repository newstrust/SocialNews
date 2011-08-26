class Admin::VisualizationsController < Admin::AdminController
  include Admin::VisualizationsHelper
  layout 'admin'

  def fetch_data_and_generate_plot_data_arrays(query_string, keys)
      # Fetch data from the db!
    db_rows = ActiveRecord::Base.connection.select_rows(query_string)

      # Massage the data into a hash of x_val => y_val mappings
      # But, yield to the caller to process the db row
    data = db_rows.inject({}) { |h,row| yield h,row; h }

      # X-axis: 50 rating values on x-axis 0.1 apart
    xs = (0..50).collect { |x| x/10.0 }

      # Plot opts
    opts = { :normalize           => params[:normalize],
             :y_aggregate         => params[:y_aggr],
             :x_aggregate         => params[:x_aggr],
             :x_aggregate_reverse => params[:x_aggr_reverse] }

      # Generate flot data array
    return get_plot_data_arrays(xs, keys, data, opts)
  end

  def rating_criteria_distribution
    db_rows = Rating.connection.select_rows("select criterion, value, count(*) as n from ratings where ratable_type='Review' group by criterion, value")
    criterion_data = db_rows.inject({}) { |h, row|
      h[row[0]] ||= {}
      h[row[0]][row[1].to_i] = row[2].to_i
      h
    }
    @data_array = {}
    @avgs = {}
    criterion_data.each { |criteria, data_hash| 
      n = 0; d = 0; data_hash.each { |k,v| n += k*v; d += v }
      out_data = get_plot_data_arrays((1..5), [], data_hash)[0]
      @avgs[criteria] = [d, format("%0.2f", n.to_f/d.to_f)]
      @data_array[criteria] = out_data
    }
  end
end
