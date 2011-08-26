var _my_page;
var _mynews_story_cache;
var _show_info;
var _curr_follow_filter;
var _curr_stype_filter;
var _saved_filter_selection;
var _starred_filter_active;
var _refresh_in_progress;
var _additional_refresh_requested;
var _pageTracker;
var story_data; // this variable is populated by listing code.
var track_mynews_event = true;

$(document).ready(function() {
  init_mynews();
});

function init_mynews() {
  _show_info = true
  var b    = $('div#info_toggle').find('a');
  var cls  = b.attr('class')
  if (cls != null) _show_info = cls.match(/show_/) ? true : false
  
//  _active_filters = { stype: null, follow: null, starred: false }
  _curr_follow_filter = null
  _curr_stype_filter  = null
  _starred_filter_active = false
  _refresh_in_progress = false
  _additional_refresh_requested = false

  init_sort_filter()

  // Init story cache
  init_story_cache()

  // Init paging
  $('.more_mynews').click(function() { 
    var button = $(this)
    var member_id = button.attr('id').replace(/more_news_/, '')
    button.pulse(true, '', true)
    fetch_more_stories(button, member_id)
    return false;
  })

  $('.filter_options_box .button').click(toggle_filter_panel);

  // JS patching of cached stories
  patch_cached_stories();

  // Google Analytics Tracker
  if (typeof(_nt_ga_tracker_code) == 'undefined')
    _nt_ga_tracker_code = "UA-1098617-1";

  _pageTracker = _gat._getTracker(_nt_ga_tracker_code);
}

function track_pageview(event_type) {
  // - Track this event -- at a coarse level initially
  // - Plus, count this is an additional page view
  try {
    _pageTracker._trackEvent('mynews', event_type);
    _pageTracker._trackPageview();
  }
  catch(err) {}
}

function track_event(event_type) {
  // - Track this event -- at a coarse level initially
  try {
    _pageTracker._trackEvent('mynews', event_type)
  }
  catch(err) {}
}

function toggle_filter_panel() {
  $('#filter_options').slideToggle(180);
  $(this).find('span').toggleClass('more').toggleClass('less');
}

function init_story_cache() {
  clear_story_cache()
  update_cache('all')
}

function clear_story_cache() {
  _mynews_story_cache = { all: null, follow_filter: null, news: null, opinion: null, msm: null, ind: null }
}

function clear_cache_entry(key) {
  _mynews_story_cache[key] = null
}

function active_cache_key() {
  return (_curr_follow_filter != null) ? 'follow_filter' : ((_curr_stype_filter != null) ? _curr_stype_filter.value : 'all')
}

function get_story_id(li) { 
//  return $(li).attr('id').replace(/story_links_/, "")
  return $(li).attr('story_id');
}

function show_more_button() {
  $('.more_link').parent().show()
}

function hide_more_button() {
  $('.more_link').parent().hide()
}

function reset_more_button() {
  var key = active_cache_key()
  if (_mynews_story_cache[key] == null || !_mynews_story_cache[key].no_more_stories) show_more_button()
  else hide_more_button()
}

// SSS: Please note, ladies and gentlemen.
// The 3 functions below (update_listing, update_listing_from_cache, and update_cache) need to work in concert.

function update_listing(listing) {
  $('ul#mynews_listing').html(listing)
}

function update_listing_from_cache(key) {
  update_listing(_mynews_story_cache[key].dom)
}

function update_cache(key) {
  var x = $('#num_stories_counter').html()
  var n = parseInt(x)
  $('#num_stories_counter').remove()

  // Merge story data and clear out new hash
  var new_sort_data = _mynews_story_cache[key] == null ? {} : _mynews_story_cache[key].sort_data
  for (id in story_data) new_sort_data[id] = story_data[id]
  story_data = {}

  var listing   = $('ul#mynews_listing')
  var story_ids = $.map(listing.find('div.story_links'), get_story_id)

  // Update cache entry
  _mynews_story_cache[key] = {
    dom : listing.children(),
    ids : story_ids,
    sort_data : new_sort_data
  }

  // No fresh stories case
  if (n == 0) {
    _mynews_story_cache[key].no_more_stories = true
    if (story_ids.length == 0) {
      if (_my_page)
        listing.html("<li><h3>No stories match your current followed items. Add more follows or update your <a href='#' onclick='toggle_filter_panel(); return false;'>settings</a>.</h3></li>")
      else
        listing.html("<li><h3>No stories match this member's current followed items.</h3></li>")
      _mynews_story_cache[key].dom = listing.children()
    }
  }
  reset_more_button()
  bind_starring_handlers()
}

// Add click handlers to clear the story cache whenever a member stars/unstars!
// We need to do this because the same story might be present in multiple cached listings
// So, if we change the starred status in one list, we need to ensure display consistency
// for this story in other cached lists!
function bind_starring_handlers() {
  $('ul#mynews_listing').find('.starred').click(function() {
    var story_li = $(this).parents('li')
    if (_starred_filter_active) story_li.hide()
    var story_id = story_li.find('div.story_links').attr('story_id');
    var key = active_cache_key()
    for (k in _mynews_story_cache) {
      if (key != k && _mynews_story_cache[k] != null) {
        _mynews_story_cache[k].dom.each(function() { $(this).find('#' + story_id).parents('li').find('.starred').toggleClass('on') })
      }
    }
    return false
  })
}

function get_ajax_stories_call_url(member_id) {
  // currently active follow_filter
  var refresh_url = '/members/' + member_id + '/mynews/stories'
  if (_curr_follow_filter != null) refresh_url += '/' + _curr_follow_filter.follow_type + '/' + _curr_follow_filter.follow_id;
  return refresh_url
}

function get_ajax_stories_call_args() {
  // currently active filter
  var params = {}
  if (_curr_stype_filter != null) params[_curr_stype_filter.name] = _curr_stype_filter.value
  return params
}

function fetch_more_stories(button, member_id) {
  // Reset starred filter, sort filter, and more button whenever you fetch more/new stories!
  reset_starred_filter()
  reset_sort_filter()
  reset_more_button()

  var cache_entry = _mynews_story_cache[active_cache_key()]
  if (cache_entry && (cache_entry.no_more_stories == true)) {
    button.pulse(false);
    hide_more_button()
    return
  }

  var args = get_ajax_stories_call_args()
  args['exclude_stories']    = (cache_entry == null) ? null : cache_entry.ids.join(", ")
  args['authenticity_token'] = encodeURIComponent(AUTH_TOKEN)
  $.ajax({
    url      : get_ajax_stories_call_url(member_id),
    type     : 'post',
    dataType : 'html',
    data     : args,
    timeout  : 15000, // 15 second timeout
    success  : function(more_stories) {
      button.pulse(false, '', true)
      $('#mynews_paging_placeholder').before(more_stories)
      update_cache(active_cache_key())
      track_pageview('more_news')
      // Use a 50 ms timeout to give the js interpreter a chance to parse everything
      setTimeout(patch_cached_stories, 50)
      try { FB.XFBML.Host.parseDomTree() } catch(err) {}
    },
    error    : function(obj, errStatus) {
      button.pulse(false);
      if (errStatus == 'timeout') alert('We are sorry! Looks like the server is busy. Please wait for about 30 seconds and try again.')
      track_event('timeout')
    }
  })
}

function refresh_mynews_listing(member_id, opts) {
  if (_refresh_in_progress) {
    _additional_refresh_requested = true
    return;
  }

  _refresh_in_progress = true;

  // Reset starred filter, sort filter, and more button whenever you fetch more/new stories!
  reset_starred_filter()
  reset_sort_filter()
  reset_more_button()

  var wg = $('div#mynews_welcome_graphic')
  if (wg) {
    wg.remove()   // now that we have content, get rid of the welcome graphic
    $('div.welcome_graphic').remove()
    $('div#main_mynews_column').show()
  }
  if (opts == null || typeof(opts.cache) == 'undefined') {
    $('ul#mynews_listing').children().remove()
    _curr_follow_filter = null
    _curr_stype_filter = null
    clear_story_cache()
  }
  else {
    $('ul#mynews_listing').children().detach()
  }
  $('ul#mynews_listing').html("<li style='margin:20px;font-size:20px;font-weight:bold;' id='loading_msg'> Updating your list ... </li>")
  $('li#loading_msg').pulse(true, '', true)

  $.ajax({
    url      : get_ajax_stories_call_url(member_id),
    type     : 'get',
    dataType : 'html',
    data     : get_ajax_stories_call_args(),
    timeout  : 15000, // 15 second timeout
    success  : function(listing) {
      var cache_key, event_key;
      if (opts != null && typeof(opts.cache) != 'undefined') {
        cache_key = opts.cache_key
        event_key = cache_key
      }
      else {
        var l = $('#all_stories_filter_link')
        l.siblings().attr('class', '')
        l.attr('class', 'sel')
        cache_key = 'all'
        event_key = 'refresh'
      }

      // Refresh the listing && update the cache (in that order!)
      update_listing(listing)
      update_cache(cache_key)
      track_pageview(event_key)
      // Use a 50 ms timeout to give the js interpreter a chance to parse everything
      setTimeout(patch_cached_stories, 50)
      try { FB.XFBML.Host.parseDomTree() } catch(err) {}

      // clear refresh flags -- and send another request to the server, if necessary.
      _refresh_in_progress = false
      if (_additional_refresh_requested) {
        _additional_refresh_requested = false
        refresh_mynews_listing(member_id, opts)
      }
    },
    error : function(obj, errStatus) {
      if (errStatus == 'timeout') alert('We are sorry! Looks like the server is busy. Please wait for about 30 seconds and reload this page to refresh your listing.')
      _refresh_in_progress = false
      _additional_refresh_requested = false
      track_event('timeout')
    }
  })
}

function apply_follow_filter(member_id, follow_type, follow_id) {
  if (follow_type) {
    // 1. Clear out the current filter!  We dont support filter + follow filters at the same time (at least now)
    // 2. Save the filter selection so we can go back to it when the follow filter is cleared
    // 3. Hide the All | News | Opinion | MSM | IND filter on top -- since we don't support both filtering & follow filter at the same time
    _saved_filter_selection = _curr_stype_filter
    _curr_stype_filter = null
    $('div#story_type_src_ownership_filters').hide()

    _curr_follow_filter = { follow_type: follow_type, follow_id: follow_id }
    refresh_mynews_listing(member_id, {cache: true, cache_key: 'follow_filter'})
  }
  else {
    _curr_follow_filter = null

    // Right now, we aren't caching projected listings -- so, we have to clear this out each time!
    clear_cache_entry('follow_filter')

    // 1. Restore the filter selection
    // 2. Show the All | News | Opinion | MSM | IND filter on top -- now that we've cleared the follow filter
    _curr_stype_filter = _saved_filter_selection
    $('div#story_type_src_ownership_filters').show()
    update_listing_from_cache((_curr_stype_filter == null ? 'all' : _curr_stype_filter.value))

    reset_starred_filter()
    init_sort_filter()
  }
}

function mynews_page_toggle_follow(button, member_id, follow_type, follow_id) {
  toggle_follow_common(button, member_id, follow_type, follow_id, function(resp) {
    if (resp.success) {
      var b = $(button)
      var cls = b.attr('class');
      if (cls.match(/_off/)) b.attr('class', cls.replace("_off", "_on"));
      else if (cls.match(/_on/)) b.attr('class', cls.replace("_on", "_off"));
      refresh_mynews_listing(member_id);
    }
    else {
      alert(resp.error);
    }
  });
  return false;
}

function toggle_story_info(div) { 
  var div   = $(div)
  var story = div.parent().parent();
  var hidden = story.find('.my_news_info:hidden');
  var show = (hidden.length > 0)

  if (show)
    story.find('a.following_off').each(function() { var c = $(this).attr('class'); $(this).attr('class', c.replace("following_off", "following")) })
  else
    story.find('a.following').each(function() { var c = $(this).attr('class'); $(this).attr('class', c.replace("following", "following_off")) })

  story.find('.my_news_info').toggle() 
  if (show) {
    div = div.find(".matches_arrow_down")
    div.removeClass('matches_arrow_down')
    div.addClass('matches_arrow_up')
  }
  else {
    div = div.find(".matches_arrow_up")
    div.removeClass('matches_arrow_up')
    div.addClass('matches_arrow_down')
  }
}

function toggle_listing_info() {
  if (_show_info) {
    $('div.my_news_info').show()
    $('a.following_off').each(function() { var c = $(this).attr('class'); $(this).attr('class', c.replace("following_off", "following")) })
    var mbs = $('div.matches_arrow_down')
    mbs.removeClass('matches_arrow_down')
    mbs.addClass('matches_arrow_up')
  }
  else {
    $('div.my_news_info').hide();
    $('a.following').each(function() { var c = $(this).attr('class'); $(this).attr('class', c.replace("following", "following_off")) })
    var mbs = $('div.matches_arrow_up')
    mbs.removeClass('matches_arrow_up')
    mbs.addClass('matches_arrow_down')
  }
}

function toggle_all_story_info(update_setting, member_id) {
  var b    = $('div#info_toggle').find('a');
  var cls  = b.attr('class')
  var show = cls.match(/show_/) ? true : false
  _show_info = show
  toggle_listing_info()
  if (update_setting) {
    $.ajax({
      url      : "/members/" + member_id + "/mynews/update_setting",
      type     : 'post', 
      dataType : 'json',
      data     : {setting: 'show_details', value: show, authenticity_token: encodeURIComponent(AUTH_TOKEN)}
    });
  }
  b.attr('class', show ? 'hide_story_info' : 'show_story_info')
  var h = b.html()
  b.html(show ? h.replace(/Show/, 'Hide') : h.replace(/Hide/, 'Show'))
  return false;
}

function clear_follow_filters() {
  // If we clicked on the filters on the top, clear out active follow_filters 
  // NOTE: It is sufficient to click the clear follow_filter hook on any of the followed items block
  // So, we are just clicking the my_tags hook.
  _curr_follow_filter = null;
  $('div.my_tags').find("#clear_follow_filters_hook").click()
}

function select_link(link, criteria) {
/*
  // Highlight the link and unhighlight siblings
  var l = $(link)
  l.siblings().attr('class', '');
  l.attr('class', 'sel');
*/
  var l = $(link)
  var ul = l.parents('ul')
  ul.find('a').attr('class', '');
  l.attr('class', 'sel');
  ul.parents('ul').find('#curr_sel').html(criteria); // update title
}

function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

function apply_stype_filter(link, member_id, p, v) {
  // Highlight the link
  select_link(link, capitalize(v));
  clear_follow_filters()
  _curr_stype_filter = (v == 'all') ? null : { name: p, value: v }

  // Now refresh the listing!
  var cache_hit;
  if (_mynews_story_cache[v] == null) {
    cache_hit = false
    refresh_mynews_listing(member_id, { cache: true, cache_key: v })
  }
  else {
    cache_hit = true
    update_listing_from_cache(v)
    // SSS FIXME: why do I need to do this here again???
    bind_starring_handlers()
    reset_starred_filter()
    init_sort_filter()
    reset_more_button()
  }

  // Reset hide/show setting
  if (cache_hit) toggle_listing_info();

  return false;
}

function apply_starred_filter() {
  // Now, selected starred items!
  var listing = $('ul#mynews_listing')
  if (_starred_filter_active) {
    hide_more_button()
    listing.find('.starred').parent().parent().hide()
    listing.find('.starred.on').parent().parent().show()
  }
  else {
    reset_more_button()
    listing.find('.starred').parent().parent().show()
  }

  // Track starred filter event unless we are coming here to reset
  if (track_mynews_event) track_event('starred');
  track_mynews_event = true
}

function toggle_starred(button) {
  _starred_filter_active = !_starred_filter_active
  _starred_filter_active ? $(button).addClass('sel') : $(button).removeClass('sel')
  apply_starred_filter()
  return false;
}

function reset_starred_filter() {
  track_mynews_event = false
  if (_starred_filter_active) toggle_starred($('#star_toggle'))
  else apply_starred_filter()
}

function init_sort_filter() {
  var link = $('div.sort_filters ul.css_dropdownm li a').first()
  select_link(link, 'Relevance')
}

function reset_sort_filter() {
  track_mynews_event = false

  // Default sort is relevance!
  var link = $('div.sort_filters ul.css_dropdownm li a').first()
  sort_listing(link, 'Relevance')
}

function get_story_data(data, li) {
  var id = get_story_id($(li).find('div.story_links'))
  var d  = data[id]
  return typeof(d) != 'undefined' ? d : null;
}

function is_empty(data) {
  for (k in data)
    return false

  return true;
}

function sort_listing(link, criteria) {
  // Highlight the link
  select_link(link, criteria)

  // Track sort event unless we are coming here to reset
  if (track_mynews_event) track_event('Sort:' + criteria);
  track_mynews_event = true

  var k = active_cache_key()
  if (_mynews_story_cache[k] == null)
    return

  var data = _mynews_story_cache[k].sort_data
  if (!is_empty(data)) {
    var dom = $('ul#mynews_listing').children('li:visible').detach()
    if (criteria == 'Relevance') {
      dom.sort(function(li1, li2) { 
        var s1 = get_story_data(data, li1)
        var s2 = get_story_data(data, li2)
        var v1 = (s1 && s2) ? s2.score - s1.score : 0
        return ((v1 == 0) && s1 && s2) ? s2.num_matches - s1.num_matches : v1 
      })
    }
    if (criteria == 'Matches') {
      dom.sort(function(li1, li2) { 
        var s1 = get_story_data(data, li1)
        var s2 = get_story_data(data, li2)
        var v1 = (s1 && s2) ? s2.num_matches - s1.num_matches : 0
        return ((v1 == 0) && s1 && s2) ? s2.score - s1.score : v1 
      })
    }
    if (criteria == 'Rating') {
      dom.sort(function(li1, li2) { 
        var s1 = get_story_data(data, li1)
        var s2 = get_story_data(data, li2)
        var v1 = (s1 && s2) ? s2.rating - s1.rating : 0
        return ((v1 == 0) && s1 && s2) ? s2.score - s1.score : v1
      })
    }
    if (criteria == 'Date') {
      dom.sort(function(li1, li2) { 
        var s1 = get_story_data(data, li1)
        var s2 = get_story_data(data, li2)
        return (s1 && s2) ? s2.sdate - s1.sdate : 0; 
      })
    }
    $('#mynews_paging_placeholder').before(dom)
  }

  // Dont cache the sorted list -- we have to worry about resetting it whenever we switch tabs, etc.
}

function toggle_fb_friends_panel()      { fb_populate_friends_form() }
function toggle_twitter_friends_panel() { twitter_populate_friends_form() }
function toggle_fb_feed_panel()         { $('a.facebook_feed').click() }
function toggle_twitter_feed_panel()    { $('a.twitter_feed').click() }
