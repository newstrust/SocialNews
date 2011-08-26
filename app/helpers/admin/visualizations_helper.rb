module Admin::VisualizationsHelper
  def get_plot_data_arrays(xs, plot_indexes, y_data, opts = {})
      # Initialize options
    opts[:x_aggregate] ||= false
    opts[:x_aggregate_reverse] ||= false
    opts[:y_aggregate] ||= false
    opts[:normalize]   ||= false
        # equal-area or equal-y-sums normalization
        # 1. Under equal-area normalization, y-values for different curves are normalized such that the
        #    total area under all curves equals 100.  This is the common kind of normalization.
        # 2. Under equal-y-sums normalization, y-values for different curves are normalized such that
        #    for each value of x, the sum y-values for all curves equals 100.  This is used for timeseries
        #    data to compare variation in data across time.
    opts[:normalize_type] ||= "equal-area"

      # If there is only 1 plot, massage the input data into the proper format expected by the iterator below
    if (plot_indexes.empty?)
      plot_indexes = ["1"]
      y_data = { "1" => y_data }
    end

      # Normalize data for all plots
    if (opts[:normalize])
      if (opts[:normalize_type] == "equal-y-sums")
        xs_sums = xs.inject({}) { |h, x| y_data.keys.each { |k| h[x] = (h[x] || 0) + (y_data[k][x] || 0) }; h }
      end

        # Normalize -- IMPT: convert to float to avoid accumulating rounding errors when x_aggregate is true!
      y_data.keys.each { |k|
        plot_data = y_data[k]
        total = plot_data.values.sum if (opts[:normalize_type] != "equal-y-sums")
        plot_data.keys.each { |r| denom = (opts[:normalize_type] != "equal-y-sums") ? total : xs_sums[r]; plot_data[r] *= (100.0 / denom) } 
      }
    end

      # Initialize y-axis aggregate data
    yaxis_aggr = xs.collect { 0 }

      # Generate data-arrays for each of the y-curves
    plot_indexes.collect { |pi|
        # Initialize x-axis aggregate data
      sum_x = (opts[:x_aggregate] && opts[:x_aggregate_reverse]) ? (y_data[pi] ? y_data[pi].values.sum : 0) : 0

        # Generate data for the current y-curve
      count = 0
      fd = xs.collect { |x|
        y = y_data[pi] ? (y_data[pi][x] || 0) : 0

          # y-aggregation
        sum_y = yaxis_aggr[count]
        count += 1

          # x-aggregation (reverse dirn)
        sum_x -= (opts[:x_aggregate] && opts[:x_aggregate_reverse] ? y : 0)

          # compute y
        y_val = y + sum_x + sum_y

          # x-aggregation (forward dirn)
        sum_x += (opts[:x_aggregate] && !opts[:x_aggregate_reverse] ? y : 0)

          # Now return data point here -- reconvert the float value to int
        [x, y_val.to_i]
      }

        # Update aggregate data along y-axis (assumes fwd direction)
      yaxis_aggr = fd.collect { |p| p[1] } if opts[:y_aggregate]

        # return the data array
      fd
    }
  end
end
