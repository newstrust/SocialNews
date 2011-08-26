require File.dirname(__FILE__) + '/../../spec_helper'

describe Discussions::CommentsController do
  describe "route generation" do

    it "should map { :controller => 'comments', :action => 'index' } to /discussions/comments" do
      route_for(:controller => "discussions/comments", :action => "index" ).should == "/comments"
    end
  
    it "should map { :controller => 'comments', :action => 'new' } to /discussions/comments/new" do
      route_for(:controller => "discussions/comments", :action => "new" ).should == "/discussions/comments/new"
    end
  
    it "should map { :controller => 'comments', :action => 'show', :id => 1  } to /discussions/comments/1" do
      route_for(:controller => "discussions/comments", :action => "show", :id => "1" ).should == {:path => "/discussions/comments/1" }
    end
  
    it "should map { :controller => 'comments', :action => 'edit', :id => 1  } to /discussions/comments/1/edit" do
      route_for(:controller => "discussions/comments", :action => "edit", :id => "1" ).should == {:path => "/discussions/comments/1/edit" }
    end
  
    it "should map { :controller => 'comments', :action => 'update', :id => 1 } to /discussions/comments/1" do
      route_for(:controller => "discussions/comments", :action => "update", :id => "1" ).should == {:path => "/discussions/comments/1", :method => :put}
    end
  
    it "should map { :controller => 'comments', :action => 'destroy', :id => 1 } to /discussions/comments/1" do
      route_for(:controller => "discussions/comments", :action => "destroy", :id => "1" ).should == {:path => "/discussions/comments/1", :method => :delete}
    end
  end

  describe "route recognition" do

    it "should generate params { :controller => 'discussions/comments', action => 'index' } from GET /discussions/comments" do
      params_from(:get, "/discussions/comments").should == {:controller => "discussions/comments", :action => "index" }
    end
  
    it "should generate params { :controller => 'discussions/comments', action => 'new', } from GET /discussions/comments/new" do
      params_from(:get, "/discussions/comments/new").should == {:controller => "discussions/comments", :action => "new" }
    end
  
    it "should generate params { :controller => 'discussions/comments', action => 'create' } from POST /discussions/comments" do
      params_from(:post, "/discussions/comments").should == {:controller => "discussions/comments", :action => "create" }
    end
  
    it "should generate params { :controller => 'discussions/comments', action => 'show', id => '1' } from GET /discussions/comments/1" do
      params_from(:get, "/discussions/comments/1").should == {:controller => "discussions/comments", :action => "show", :id => "1" }
    end
  
    it "should generate params { :controller => 'discussions/comments', action => 'edit', id => '1' } from GET /discussions/comments/1;edit" do
      params_from(:get, "/discussions/comments/1/edit").should == {:controller => "discussions/comments", :action => "edit", :id => "1" }
    end
  
    it "should generate params { :controller => 'discussions/comments', action => 'update', id => '1' } from PUT /discussions/comments/1" do
      params_from(:put, "/discussions/comments/1").should == {:controller => "discussions/comments", :action => "update", :id => "1" }
    end
  
    it "should generate params { :controller => 'discussions/comments', action => 'destroy', id => '1' } from DELETE /discussions/comments/1" do
      params_from(:delete, "/discussions/comments/1").should == {:controller => "discussions/comments", :action => "destroy", :id => "1" }
    end
  end
end
