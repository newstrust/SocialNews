# SSS: Treat this table as an eventually consistent cache for aggregate statistics.
# We dont need these statistics to be always accurate and up-to-date.  So, all requests
# for aggregate info that are found here will be considered a hit.  If we dont find an
# entry in the table, we compute the aggregate statistic and store it in a non-stale state.
# After this initial miss, we NEVER clear out aggregate statistics from the table. 
#
# We independently run a periodic cron job that checks the age of aggregate statistics
# and recomputes those that are more than X hours old.  The recompute rake task computes
# fresh statistics on a per-model & per-statistic basis.  See STATISTICS constant below.
#
# That is all there is to it.

class AggregateStatistic < ActiveRecord::Base
  belongs_to :model, :polymorphic => true

  # This array is used for refreshing stats in a background job
  # Only these stats are updated!
  STATISTICS = [
    { :model_type => "Subject",   :name => "top_sources",              :max_age => 12.hours },
    { :model_type => "Topic",     :name => "top_sources",              :max_age => 12.hours },
    { :model_type => "Topic",     :name => "taggings_count",           :max_age => 6.hours },
    { :model_type => "Feed",      :name => "avg_feed_rating",          :max_age => 24.hours },
    { :model_type => "Feed",      :name => "num_trusted_feed_stories", :max_age => 4.hours  },
    { :model_type => "LocalSite", :name => "active_topics_by_subject", :max_age => 6.hours  },
    { :model_type => "Source",    :name => "topic_expertise",          :max_age => 1.hour },
    { :model_type => "Source",    :name => "top_authors",              :max_age => 24.hours },
    { :model_type => "Source",    :name => "top_formats",              :max_age => 24.hours },
    { :model_type => "Source",    :name => "top_topics",               :max_age => 24.hours },
  ]

  def refresh
    # Force update of the updated_at timestamp so that we explicitly record the fact that we recomputed the value.
    # Otherwise, since the value itself might remain unchanged, the db update wont be performed.
    update_attributes(:value => ObjectHelpers.marshal(arg ? model.send(statistic, arg) : model.send(statistic)), :updated_at => Time.now)
  end

  def self.find_statistic(model, statistic, arg=nil)
    as = AggregateStatistic.find(:first, :conditions => {:model_type => model.class.name, :model_id => model.id, :statistic => statistic, :arg => arg})
    begin 
      if as
        ObjectHelpers.unmarshal(as.value)
      else
        as = arg ? model.send(statistic, arg) : model.send(statistic)
        AggregateStatistic.create(:model_type => model.class.name, :model_id => model.id, :statistic => statistic, :value => ObjectHelpers.marshal(as), :arg => arg)
        as
      end
    rescue Exception => e
      # retry if we failed to load cached value correctly!
      if as
        as.destroy
        as = nil
        RAILS_DEFAULT_LOGGER.error "#{e} while finding statistic #{statistic} for #{model.class.name}:#{model.id}:#{arg}.  Retrying!"
        retry
      end
    end
  end
end
