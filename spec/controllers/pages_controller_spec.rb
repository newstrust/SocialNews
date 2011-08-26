require File.dirname(__FILE__) + '/../spec_helper'

describe PagesController do
  describe 'handling GET or POST /search' do
    it "should get search page, when no queries are provided" do
      get :search
      response.should be_success
      response.should render_template('search')
      
      post :search
      response.should be_success
      response.should render_template('search')
    end      
    
    it "should display search results, when queries are provided" do
        # SSS: IMPORTANT: Don't replace this line with
        #    ThinkingSphinx::Search.stub!(:search).and_return([])
        # Even though they look similar, they are not!  The difference is subtle but important.
        # The code-block below ensures that we return a new value each time search is called
        # With the non-block code above, we return the same empty array object which breaks
        # the search code in the controller
      ThinkingSphinx::Search.stub!(:search).and_return { [] }
      get :search, :id => 'foo'
      response.should render_template('results')
      
      post :search, :id => 'foo'
      response.should render_template('results')
    end
    
    it "should display an error if the search engine is not running" do
      ThinkingSphinx::Search.stub!(:search).and_raise(ThinkingSphinx::ConnectionError)
      post :search, :id => 'foo'
      response.should render_template('pages/search_error')
      response.flash[:error].should_not be_nil
    end
  end
  
  describe 'handling GET or POST /scoped_search' do
    it "should display an error if a model is not provided" do
      get :scoped_search
      response.should redirect_to(search_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should display an error if an invalid model is used" do
      get :scoped_search, :type => 'FOO'
      response.should redirect_to(search_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should display an error when no query is provided" do
      get :scoped_search, :type => 'Story'
      response.should redirect_to(search_path)
      response.flash[:error].should_not be_nil
    end
    
    it "should display the results of a scoped search if a valid model and query are provided" do
      ThinkingSphinx::Search.stub!(:search).and_return([])
      get :scoped_search, :type => 'Story', :q => 'foo'
      response.should be_success
      response.flash[:error].should be_nil
      response.should render_template('results')
    end
  end
  
  describe 'routing tests' do
    it "should map { :controller => 'pages', :action => 'search' } to /search" do
      route_for(:controller => "pages", :action => "search" ).should == {:path => "/search"}
    end
    
    it "should generate params { :controller => 'pages', action => 'search' } from GET /search" do
      params_from(:get, "/search").should == {:controller => "pages", :action => "search" }
    end
  end
end
