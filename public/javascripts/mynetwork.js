var _tabs_empty = null
var _listing_cache;
var _network_tab_cache = null;
var _curr_filter = null;
var _refresh_in_progress;
var _additional_refresh_requested;
var last_activity_entry_id;
var hide_pagination = false;

$(document).ready(function() {
  init_activity_listings();
});

function init_activity_listings() {
  empty_tabs()
  _tabs_empty.network           = false
  _tabs_empty.followers         = false
  _tabs_empty.followed_members  = false
  reset_cache()
  update_cache()
  _refresh_in_progress          = false
  _additional_refresh_requested = false

  // Init paging
  $('.more_activity').click(function() { 
    var button = $(this)
    var member_id = button.attr('id').replace(/more_activity_/, '')
    button.pulse(true, '', true)
    fetch_more_activity(button, member_id)
    return false;
  })
}

// SSS: Please note, ladies and gentlemen.
// The 3 functions below (update_listing, update_network_activity_from_cache, and update_cache) need to work in concert.
//
// If you want this code to work on IE7 and IE8, please note that you need to clone the DOM that you want to
// cache and re-attach later on.
//
// So, even though it might seem like:
//
//    x = l.children().clone(true)
//    l.children.remove()
//
// is identical in functionality to:
//
//    x = l.children()
//    l.children().detach()
//
// For the purposes of reattaching x later on, detaching doesn't work as expected on IE7 and IE8.  The former
// technique (clone & remove) works, whereas the latter (detach) doesn't.  You end up with a shallow copy of
// the children that gets reattached (just empty useless <li></li> soulless dead bodies).
//
// FIXME: But, makes this damn thing expensive because of the useless cloning -- maybe make this browser specific?

function update_listing(tab, listing) {
  var l = $('ul#' + tab + '_listing')
  l.children().remove()
  l.append(listing)
  _tabs_empty[tab] = false
}

function update_network_activity_from_cache() {
  var k = active_cache_key()
  var l = _network_tab_cache[k].dom
  update_listing('network', l)
  _network_tab_cache[k].dom = l.clone(true) // refresh cache entry!
}

function active_cache_key() {
  return _curr_filter == null ? 'all' : 'follow_filter'
}

function reset_cache() {
  _network_tab_cache = { all: {}, follow_filter: {}}
}

function update_cache() {
  var k = active_cache_key()
  // At this time, no need to cache anything but the full listing!
  if (k == 'all') _network_tab_cache[k].dom = $('ul#network_listing').children().clone(true)
  _network_tab_cache[k].no_more_stories = hide_pagination
  reset_more_button()
}

function show_more_button() {
  $('.more_link').parent().show()
}

function hide_more_button() {
  $('.more_link').parent().hide()
}

function reset_more_button() {
  var k = active_cache_key()
  if (_network_tab_cache[k].no_more_stories) hide_more_button() // No more activity entries!
  else show_more_button()
}

function empty_tabs() {
  // Followers will not get stale because of people I follow or unfollow!
  // But, the add/remove buttons might need to be updated -- simple to just refetch!
  _tabs_empty = { network: true, followers: true, followed_members: true }
  reset_cache()
}

function switch_activity_tab(member_id, tab, params) {
  if (_tabs_empty[tab]) {
    $('ul#' + tab + '_listing').html("<li style='margin:20px;font-size:20px;font-weight:bold;' id='loading_msg'> Updating ... </li>")
    $('li#loading_msg').pulse(true, '', true)
    $.ajax({
      url      : '/members/' + member_id + '/' + tab + '_activity_ajax_listing',
      type     : 'get',
      dataType : 'html',
      data     : params,
      success  : function(listing) {
        update_listing(tab, listing)
        if (tab == 'network') update_cache()

        // clear refresh flags -- and send another request to the server, if necessary.
        _refresh_in_progress = false
        if (_additional_refresh_requested) {
          _additional_refresh_requested = false
          refresh_network_listings(member_id)
        }
      },
      error : function(obj, errStatus) {
        if (errStatus == 'timeout') alert('We are sorry! Looks like the server is busy. Please wait for about 30 seconds and try again.')
        _refresh_in_progress = false
        _additional_refresh_requested = false
      }
    })
  }
}

function refresh_network_listings(member_id) {
  if (_refresh_in_progress) {
    _additional_refresh_requested = true
    return;
  }

  _refresh_in_progress = true;
  empty_tabs()
  $("li.firstTab a").click()
}

function filter_activity_by_member(my_id, follow_type, other_member_id) {
  if (follow_type) {
    _tabs_empty['network'] = true
    _curr_filter = { follow_type: follow_type, follow_id: other_member_id }
    switch_activity_tab(my_id, 'network', {member_id: other_member_id})
  }
  else {
    _curr_filter = null
    reset_more_button()
    update_network_activity_from_cache()
  }
}

function fetch_more_activity(button, member_id) {
  params = {last_activity_entry_id: last_activity_entry_id}
  if (_curr_filter != null) params.member_id = _curr_filter.follow_id
  $.ajax({
    url      : '/members/' + member_id + '/network_activity_ajax_listing',
    type     : 'get',
    dataType : 'html',
    data     : params,
    success  : function(entries) {
      button.pulse(false, '', true)
      $('#activity_paging_placeholder').before(entries)
      update_cache()
    },
    error : function(obj, errStatus) {
      if (errStatus == 'timeout') alert('We are sorry! Looks like the server is busy. Please wait for about 30 seconds and try again.')
    }
  })
}
