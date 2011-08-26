require File.dirname(__FILE__) + '/../spec_helper'

describe Newsletter do
  fixtures :newsletters, :members, :sources, :source_media, :layout_settings, :topics, :stories

  before(:each) do
    @daily  = newsletters(:daily_auto)
    @weekly = newsletters(:weekly_ready)
    @member = members(:heavysixer)
  end

  it 'should correctly indicate whether a newsletter is dispatchable' do
    @daily.can_dispatch?.should be_true
    @daily.state = Newsletter::READY
    @daily.can_dispatch?.should be_true
    @daily.mark_in_transit
    @daily.can_dispatch?.should be_true
    @daily.mark_sent
    @daily.can_dispatch?.should be_false
  end

  it 'should only fetch prepared newsletters for dispatch' do
    Newsletter.fetch_prepared_newsletter(Newsletter::DAILY).id.should == @daily.id
    @daily.mark_in_transit
    Newsletter.fetch_prepared_newsletter(Newsletter::DAILY).id.should == @daily.id
    @daily.mark_sent
    Newsletter.fetch_prepared_newsletter(Newsletter::DAILY).should be_nil
  end

  it 'should, when requested for a newsletter, fetch an existing unsent newsletter when one exists' do
    nl = Newsletter.fetch_latest_newsletter(Newsletter::DAILY, @member)
    nl.id.should == @daily.id
  end

  it 'should, when requested for a newsletter, create a new newsletter when none exists' do
    @daily.mark_sent
    nl = Newsletter.fetch_latest_newsletter(Newsletter::DAILY, @member)
    nl.id.should_not == @daily.id
    nl.state.should == Newsletter::READY
    nl.add_top_story_title_to_subject.should be_true
  end

  it 'should set state to AUTO when newsletter is fetched by the newsletter bot' do
    @daily.mark_sent
    nl = Newsletter.fetch_latest_newsletter(Newsletter::DAILY, Member.nt_bot)
    nl.id.should_not == @daily.id
    nl.state.should == Newsletter::AUTO
  end

  it 'should set dispatch times for new newsletters' do
    @daily.mark_sent
    nl = Newsletter.fetch_latest_newsletter(Newsletter::DAILY, @member)
    nl.dispatch_time.should_not be_nil
    nl.mark_sent
    nl = Newsletter.fetch_latest_newsletter(Newsletter::DAILY, Member.nt_bot)
    nl.dispatch_time.should_not be_nil
  end

  it 'should assign headers and footers from previous newsletters rather than from a template' do
    @daily.mark_sent
    nl = Newsletter.fetch_latest_newsletter(Newsletter::DAILY, @member)
    nl.subject.should == @daily.subject
    nl.text_header.should == @daily.text_header
    nl.text_footer.should == @daily.text_footer
    nl.html_header.should == @daily.html_header
    nl.html_footer.should == @daily.html_footer
  end

  it 'should ensure that there are stories in the newsletter' do
      # Make sure there are stories in the db
    Story.find(:all).size.should > 0

      # update stories to today's date & refresh newsletter stories so that we get stories in the newsletter 
    Story.find(:all).each { |s| s.story_date = Time.now; s.save! }
    @daily.refresh_stories
    @daily.most_recent_news_msm.size.should > 0
  end

  it 'should refresh stories when refreshed in the context of newly added stories' do
      # Since the fixture has no stories, first set up its stories and get most_recent
    @daily.refresh_stories
    tp1 = @daily.most_recent_news_msm

      # add a new story -- pick a source different from existing stories
      # so that the new story is not rejected by the source uniqueness constraint
    ns = Story.create({
      :title => "Test story",
      :url => "http://no.where.to.go",
      :story_type => "special_report",
      :story_date => Time.now,
      :editorial_priority => 3,
      :rating => 4.5,
      :authorships => [Authorship.new(:source_id => 2)]})
    ns.save!
    
      # refresh and get new most_recent
    @daily.refresh_stories
    tp2 = @daily.most_recent_news_msm
    tp2.should_not == tp1

      # new today's picks should contain the new story
    tp2.find {|s| s.id == ns.id}.should_not be_nil
  end

  it 'should ensure that sources appears only once in all listings in the newsletter' do
      # update stories to today's date & refresh newsletter stories so that we get stories in the newsletter 
    Story.find(:all).each { |s| s.story_date = Time.now; s.save! }
    @daily.refresh_stories

    ["most_recent", "most_trusted"].each { |lt| 
      [Story::NEWS, Story::OPINION].each { |st| 
          # collect all story sources -- reset for each listing section
        sources = []
        [Source::MSM, Source::IND].each { |so| sources += @daily.stories(lt, st, so).collect { |s| s.primary_source.id } } 
        #FIXME: Turning this off for now, because the fixtures don't cover all sections when checked at this fine granularity
        #sources.size.should > 0 # make sure there are sources
        sources.should == sources.uniq
      }
    }
  end

  it 'should not repeat stories in the newsletter' do
      # update stories to today's date & refresh newsletter stories so that we get stories in the newsletter 
    Story.find(:all).each { |s| s.story_date = Time.now; s.save! }
    @daily.refresh_stories

    stories = []
    ["most_recent", "most_trusted"].each { |lt| 
      [Story::NEWS, Story::OPINION].each { |st|
        [Source::MSM, Source::IND].each { |so| stories += @daily.stories(lt, st, so).collect { |s| s.id } }
      }
    }
    stories.should == stories.uniq
  end

  it 'should compute daily dispatch times correctly' do
      # Stub Time.now so that Time.now always returns a time before the daily delivery time
    now_hour = Newsletter::DELIVERY_TIMES[Newsletter::DAILY]["hour"] - 1
    d = Time.parse("#{now_hour}:00")
    Time.stub!(:now).and_return(d)

      # Test 1 -- now is before regular dispatch time
    tnow = Time.now
    tnext = Newsletter.get_next_dispatch_time(Newsletter::DAILY)

      # Verify dispatch time requirements
    tnext.should > tnow
    tnext.hour.should == Newsletter::DELIVERY_TIMES[Newsletter::DAILY]["hour"]
    tnext.min.should  == Newsletter::DELIVERY_TIMES[Newsletter::DAILY]["min"]
    curr_day = tnow.to_date.cwday
    tnext_day = tnext.to_date.cwday
       ((curr_day != Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["day"]) && (tnext_day.should == curr_day)) \
    || ((curr_day == Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["day"]) && (tnext_day.should == 1+curr_day%7))

      # Stub Time.now so that Time.now always returns a time after the daily delivery time
    now_hour = Newsletter::DELIVERY_TIMES[Newsletter::DAILY]["hour"] + 1
    d = Time.parse("#{now_hour}:00")
    Time.stub!(:now).and_return(d)

      # Test 2 -- now is after regular dispatch time
    tnow = Time.now
    tnext = Newsletter.get_next_dispatch_time(Newsletter::DAILY)

      # Verify dispatch time requirements
    tnext.should > tnow
    tnext.hour.should == Newsletter::DELIVERY_TIMES[Newsletter::DAILY]["hour"]
    tnext.min.should  == Newsletter::DELIVERY_TIMES[Newsletter::DAILY]["min"]
    curr_day = tnow.to_date.cwday
    tnext_day = tnext.to_date.cwday
       ((curr_day != (Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["day"]-1)%7) && (tnext_day.should == 1+curr_day%7)) \
    || ((curr_day == (Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["day"]-1)%7) && (tnext_day.should == 1+(curr_day+1)%7))
  end

  it 'should not schedule more than one daily newsletter the same day even when newsletters are sent out-of-regular-schedule' do
    now_hour = Newsletter::DELIVERY_TIMES[Newsletter::DAILY]["hour"] - 1
    d = Time.parse("#{now_hour}:00")
    Time.stub!(:now).and_return(d)

      ## Set its dispatch time 2 hours before its scheduled time
    now_hour = Newsletter::DELIVERY_TIMES[Newsletter::DAILY]["hour"] - 2
    @daily.dispatch_time = Time.parse("#{now_hour}:00")
    @daily.state = Newsletter::SENT
    @daily.save

    tnext = Newsletter.get_next_dispatch_time(Newsletter::DAILY)
    curr_day  = @daily.dispatch_time.to_date.cwday
    tnext_day = tnext.to_date.cwday
       ((curr_day != (Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["day"]-1)%7) && (tnext_day.should == 1+curr_day%7)) \
    || ((curr_day == (Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["day"]-1)%7) && (tnext_day.should == 1+(curr_day+1)%7))

      ## Set its dispatch time 2 hours after the scheduled time
    now_hour = Newsletter::DELIVERY_TIMES[Newsletter::DAILY]["hour"] + 2
    @daily.dispatch_time = Time.parse("#{now_hour}:00")
    @daily.state = Newsletter::SENT
    @daily.save

    tnext = Newsletter.get_next_dispatch_time(Newsletter::DAILY)
    curr_day  = @daily.dispatch_time.to_date.cwday
    tnext_day = tnext.to_date.cwday
       ((curr_day != (Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["day"]-1)%7) && (tnext_day.should == 1+curr_day%7)) \
    || ((curr_day == (Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["day"]-1)%7) && (tnext_day.should == 1+(curr_day+1)%7))
  end

  it 'should compute weekly dispatch times correctly' do
    tnow = Time.now
    tnext = Newsletter.get_next_dispatch_time(Newsletter::WEEKLY)
    tnext.should > tnow
    tnext.hour.should == Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["hour"]
    tnext.min.should  == Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["min"]
    tnext.to_date.cwday.should == Newsletter::DELIVERY_TIMES[Newsletter::WEEKLY]["day"]
  end

  it 'should correctly record delivery notices' do
    @daily.record_delivery_notice(@member)
    dn = @daily.get_delivery_notice(@member)
    dn.should_not be_nil
  end
end
