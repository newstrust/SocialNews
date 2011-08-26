require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "ActiveRecord Model composed of virtual attributes" do
  it 'should set virtual attributes' do
    u = User.new
    u.money = Money.new 1, 'usd'
    u.virtual_amount.should == 1
    u.virtual_currency.should == 'usd'
  end
  
  it 'should get from virtual attributes' do
    u = User.new
    u.virtual_amount = 1
    u.virtual_currency = 'usd'
    u.money.should == Money.new(1, 'usd')
  end
end

begin
  class Foo < ActiveRecord::Base
    composed_of :money, :mapping=>[%w(virtual_amount amount), %w(virtual_currency currency)],
                :converter=>lambda {|v| Money.new(v.split(/ /).first.to_i, v.split(/ /).last) }
                
    composed_of :money2, :class_name=>'Money', :mapping=>[%w(virtual_amount amount), %w(virtual_currency currency)],
                :converter=>:make
                
    composed_of :money3, :class_name=>'Money', :mapping=>[%w(virtual_amount amount), %w(virtual_currency currency)],
                :constructor=>lambda {|*args| Money.new(*args)}
                
    attr_accessor :virtual_amount, :virtual_currency
  end
  
  describe 'Composed ActiveRecord Model with converter' do
    it 'should use proc converter' do
      f = Foo.new
      f.money = '1 usd'
      f.money.should == Money.new(1, 'usd')
      f.virtual_amount.should == 1
      f.virtual_currency.should == 'usd'
    end
    
    it 'should use symbol converter' do
      f = Foo.new
      f.money2 = '1 usd'
      f.money.should == Money.new(1, 'usd')
      f.virtual_amount.should == 1
      f.virtual_currency.should == 'usd'
    end
    
    it 'should raise when converter not symbol, method or proc' do
      lambda {
        Foo.send(:composed_of, :money4, :class_name=>'Money', :mapping=>[%w(virtual_amount amount), %w(virtual_currency currency)], :converter=>1)
        Foo.new.money4 = 2
      }.should raise_error(ArgumentError)
    end
  end
  
  describe 'Composed ActiveRecord Model with constructor' do
    it 'should use proc constructor' do
      f = Foo.new
      f.virtual_amount = 1
      f.virtual_currency = 'usd'
      f.money3.should == Money.new(1, 'usd')
    end
    
    it 'should raise when constructor not symbol, method or proc' do
      lambda {
        Foo.send(:composed_of, :money5, :class_name=>'Money', :mapping=>[%w(virtual_amount amount), %w(virtual_currency currency)], :constructor=>1)
        Foo.new.money5
      }.should raise_error(ArgumentError)
    end
  end
rescue ArgumentError
  puts 'Not testing composed_of with :constructor and :converter since current ActiveRecord version does not support it'
end