require File.dirname(__FILE__) + '/../spec_helper'

class PJ_MockModel
  @@model = PJ_MockModel.new
  def self.find(*args); @@model; end
  def id; 1; end
  def save!; end
end

describe ProcessJob do
  it "should call processor method if present" do
    PJ_MockModel.find(1).should_receive(:doit).with(nil)
    ProcessJob.new(:processable_type => "PJ_MockModel", :processable_id => 1, :processor_method => "doit").process
  end

  it "should call save_and_process_with_propagation if processor method is not present" do
    PJ_MockModel.find(1).should_receive(:save_and_process_with_propagation).with(false, nil)
    ProcessJob.new(:processable_type => "PJ_MockModel", :processable_id => 1).process
  end
end
