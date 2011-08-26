# 
# RatingProcessor
# 
# Business logic for calculating (float) ProcessedRatings for all 'Processable' classes
# from (integer) user-entered Ratings.
#
# dispatches to the individual 'processor' classes & provides general tools for them
# 

module Ratings

  class << self
    def get_processor(processable, online_request, group)
      const_get("#{processable.class.name}Processor").new(processable, online_request, group)
    end

    # Fire up appropriate Processor subclass for this model, then return ratings hash
    # online_request: this is a request that originated from a web http request => minimal processing
    # if not, it is an offline request, and we can take all the time in the world
    def process(processable, online_request, group)
      get_processor(processable, online_request, group).process
    end

    def do_quick_approx_propagation(processable, online_request, group)
      get_processor(processable, online_request, group).do_quick_approx_propagation
    end
  end

  # base class
  class Processor
    # quick and approximate propagation for online requests -- so members get quick and approximate feedback
    # Every processor might override this to provide its own quick and approximate propagation
    def do_quick_approx_propagation
    end
  end

  protected

    # utility function, since we do weighted averages everywhere
    # note that the weights are considered RELATIVE to each other...
    # may need a scheme for defining an absolute range in cases
    # Once we hammer out the math, consider doing this at the SQL level if it's faster
    def self.do_weighted_average(weight_value_pairs)
      return nil if weight_value_pairs.empty?

      sum = divisor = 0.0
      weight_value_pairs.each do |wvp|
        sum += wvp[:value] * wvp[:weight]
        divisor += wvp[:weight]
      end
      divisor = 1 if divisor.zero?
      return sum / divisor
    end

    def self.do_average(values)
      values.empty? ? nil : values.sum / values.length
    end

end
