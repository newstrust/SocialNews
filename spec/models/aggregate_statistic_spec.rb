require File.dirname(__FILE__) + '/../spec_helper'

class AS_MockModel
  @@model = AS_MockModel.new
  def self.find(*args); @@model; end
  def id; 1; end
  def new_record?; false; end  # For some reason, this is called .. not sure why
end

describe AggregateStatistic do
  describe "find_statistic" do
    describe "with no args" do
      it "should build the statistic if none exists" do
        mm = AS_MockModel.find(1)
        mm.should_receive(:stat_no_arg).and_return { 42 }
        lambda do
          AggregateStatistic.find_statistic(mm, "stat_no_arg").should == 42
        end.should change(AggregateStatistic, :count).by(1)
      end

      it "should return the statistic from the database if one exists" do
        mm = AS_MockModel.find(1)
        mm.should_receive(:stat_no_arg).once.and_return { 42 }
        lambda do
          AggregateStatistic.find_statistic(mm, "stat_no_arg").should == 42
        end.should change(AggregateStatistic, :count).by(1)
        lambda do
          AggregateStatistic.find_statistic(mm, "stat_no_arg").should == 42
        end.should_not change(AggregateStatistic, :count)
      end
    end

    describe "with one arg" do
      it "should build the statistic if none exists" do
        mm = AS_MockModel.find(1)
        mm.should_receive(:stat_one_arg).with(10).and_return { 45 }
        lambda do
          AggregateStatistic.find_statistic(mm, "stat_one_arg", 10).should == 45
        end.should change(AggregateStatistic, :count).by(1)
      end

      it "should return the statistic from the database if one exists" do
        mm = AS_MockModel.find(1)
        mm.should_receive(:stat_one_arg).once.with(10).and_return { 45 }
        lambda do
          AggregateStatistic.find_statistic(mm, "stat_one_arg", 10).should == 45
        end.should change(AggregateStatistic, :count).by(1)
        lambda do
          AggregateStatistic.find_statistic(mm, "stat_one_arg", 10).should == 45
        end.should_not change(AggregateStatistic, :count)
      end
    end
  end

  describe "refresh" do
    it "should recompute the statistic" do
      mm = AS_MockModel.find(1)
      mm.should_receive(:stat_no_arg).twice.and_return { Time.now }

      # Seed the db
      old_val = nil
      lambda do
        old_val = AggregateStatistic.find_statistic(mm, "stat_no_arg")
      end.should change(AggregateStatistic, :count).by(1)

      # Verify that refetching the stat returns the old value, refresh and verify that the value has changed
      lambda do
        AggregateStatistic.find_statistic(mm, "stat_no_arg").should == old_val
        AggregateStatistic.find(:last).refresh
        AggregateStatistic.find_statistic(mm, "stat_no_arg").should_not == old_val
      end.should_not change(AggregateStatistic, :count)
    end
  end
end
