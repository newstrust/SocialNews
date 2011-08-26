require 'rubygems'
require 'spec'
gem 'activerecord', '>= 2'
require 'active_record'

require "#{File.dirname(__FILE__)}/../init"

ActiveRecord::Base.establish_connection(:adapter=>'sqlite3', :dbfile=>':memory:')

load(File.dirname(__FILE__) + "/schema.rb")

class Document < ActiveRecord::Base
  has_eav_behavior

  def is_eav_attribute?(attr_name, model)
    attr_name =~ /attr$/
  end
end

class Person < ActiveRecord::Base
  has_eav_behavior :class_name => 'Preference', 
                   :name_field => :key
                   
  has_eav_behavior :class_name => 'PersonContactInfo', 
                   :foreign_key => :contact_id, 
                   :fields => %w(phone aim icq)

  def eav_attributes(model)
    model == Preference ? %w(project_search project_order) : nil
  end
end

class Post < ActiveRecord::Base
  has_eav_behavior
  
  validates_presence_of :intro, :message => "can't be blank", :on => :create
end

class User < ActiveRecord::Base
  has_attributes :meta_columns=>{:private=>{:type=>:boolean, :default=>true}, :multiplyer=>{:type=>:integer, :default=>1}, :multiple=>:virtual}
  
  composed_of :money, :mapping=>[%w(virtual_amount amount), %w(virtual_currency currency)]
  
  attr_accessor :virtual_amount, :virtual_currency
end

class Multiple
  attr_reader :value, :multiplyer
  
  def initialize value, multiplyer
    @multiplyer = multiplyer.to_i
    @value = value.to_i * @multiplyer
  end
  
  def == other
    value == other.value && multiplyer == other.multiplyer
  end
end

class UserAttribute < ActiveRecord::Base
  composed_of :multiple, :class_name=>'Multiple', :mapping=>[%w(value value), %w(multiplyer multiplyer)], :allow_nil=>true
end

class Money
  attr_reader :amount, :currency
  
  def initialize amount, currency
    @amount = amount
    @currency = currency
  end
  
  def self.make value
    amount, currency = value.split(/ /)
    Money.new amount.to_i, currency
  end
  
  def == other
    amount == other.amount && currency == other.currency
  end
end