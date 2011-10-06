var app_name = "SocialNews";
$(document).ready(function() { $("#fb_follow_friends_link").click(function() { return fb_populate_friends_form() }) })

var curr_stream_story = null;
function fb_publish_to_user_stream(s) {
  curr_stream_story = s

  // convert the array of key-value pairs into a js hash
  var props = s.properties
  var new_props = {}
  for (i = 0; i < props.length; i++) {
    var elt = props[i]
    new_props[elt[0]] = elt[1]
  }

  // build the feed obj
  var feed_obj = {
    method: 'feed',
    name: s.name,
    link: s.link,
    caption: s.caption,
    description: s.description,
    properties: new_props,
    actions: s.actions,
    message: s.message,
  }

  // publish!
  FB.ui(feed_obj, fb_review_posted)
}

function fb_review_posted(response) {
  if ((response != null) && (response.post_id != null) && (response.post_id != "null")) {
    $.ajax({
      url      : '/members/record_fb_stream_post',
      type     : 'post',
      dataType : 'json',
      data     : {authenticity_token: encodeURIComponent(AUTH_TOKEN), post_type: 'review', review_id: curr_stream_story.comments_xid }
    })
  }
}

function fb_populate_friends_form() {
  var follow_link = $("#fb_follow_friends_link")
  $("#fb_friends_notice").html('').hide() 
  $(".fb_error_msg").hide()
  follow_link.pulse(true, '', true)
  $.ajax({
    url      : '/fb_connect/followable_friends.js',
    type     : 'get',
    dataType : 'json',
    timeout  : 15000, // 15 second timeout
    success  : function(resp) {
      follow_link.pulse(false, '', true)
      follow_link.unbind("click").click(function() { return fb_close_follow_friends_form() })
      var fbf_box = $("#fb_friends_box")
      fbf_box.show()
      if (resp.error != null) {
        fbf_box.find("#" + resp.error).show()
      }
      else {
        $("#fb_friends_form").show()
        var container_div = $("#fb_followable_friends")
        for (var i = 0; i < resp.members.length; i++) {
          var elt = resp.members[i]
          var div = $.create('div', {'class': 'friend_row'}, '')
          // This doesn't work in IE7/IE8 .. hence using a html string below
          // div.append($.create('input', {'type': 'checkbox', 'name': 'follow_ids[' + elt.id + ']', 'value': 1, 'checked': 'checked', 'class': 'check', 'style': 'float:left'}, ''))
          div.append($('<input type="checkbox" name="follow_ids[' + elt.id + ']" value="1" checked="checked" class="check" style="float:left" />'));
          var span = $.create('span', '', '');
          if (elt.icon) {
            var img_attrs = { 'class': 'small_thumb', 'style': 'background-image:url(' + elt.icon + ');' }
            span.append($.create('span', img_attrs, ''));
          }
          span.append(elt.name)
          div.append(span)
          container_div.append(div)
        }
      }
    },
    error : function(obj, errStatus) {
      follow_link.pulse(false, '', true)
      if (errStatus == 'timeout') alert('We are sorry!  Looks like ' + app_name + ' or Facebook servers are loaded. Please try again in a little while.')
    }
  })

  return false;
}

function fb_follow_friends() {
  var form = $("#fb_friends_form")
  var form_data = form.serialize()
  var notice = $("#fb_friends_notice")
  notice.html("Adding ...").show().pulse(true, '', true)
  $.ajax({
    url      : '/mynews/bulk_follow.js',
    type     : 'post',
    data     : form_data,
    dataType : 'json',
    success  : function(resp) {
      notice.pulse(false, '', true).html('').hide()

      // Add members to the followed members lists
      var container = $('div#my_members')
      for (var i = 0; i < resp.items.length; i++) {
        var m = resp.items[i]
        m.dont_refresh_flag = true // No refresh 
        add_follow(container, m)
      }

      // Reset the form to a usable state!
      fb_close_follow_friends_form()

      // Refresh listing
      container.find("#refresh_listing_hook").click();
    }
  })
  return false;
}

function fb_close_follow_friends_form() {
  // Remove all followable friend elements we added
  $("#fb_followable_friends").children().remove()

  // Hide the form
  var form = $("#fb_friends_form")
  form.hide()
  form.parent().hide()

  // Reset the click event handler
  $("#fb_follow_friends_link").unbind("click").click(function() { return fb_populate_friends_form() })

  return false;
}

function fb_request_extended_permission(check_box, ep) {
  var cb = $(check_box)
  FB.login(function(response) {
     if (response.authResponse) {
       cb.attr("checked", "checked")
       $("#ep_" + ep).children().hide()
       $("#ep_" + ep).find("#granted").show()
     } else {
       cb.attr("checked", "")
     }
  }, {scope: ep});
}

function fb_permissions_dialog_fixup_hack() {
  $('.fb_connect_dialog_iframe').attr('scrolling', 'yes').css('height', '375px').attr('scrolling', 'no')
}

function request_extended_perms_common(button, post_update_function) {
  needed_eps = "read_stream,offline_access"
  FB.login(function(response) {
    if (response.authResponse) {
       $.ajax({
         url      : '/fb_connect/update_extended_perms.js',
         type     : 'post',
         data     : { authenticity_token: encodeURIComponent(AUTH_TOKEN), granted_perms: needed_eps },
         dataType : 'json',
         success  : post_update_function
       })
     }
     else {
       if (button) $(button).pulse(false)
       alert("We are sorry!  You cannot follow your Facebook network feed without granting all necessary permissions!  We only extract news links from your stream and do not store anything else in our database!  If you change your mind, click on the button again.");
     }
  }, {scope: needed_eps});

  return false;
}

// The member wants to add their facebook feed.  Well and good!
// Ask for perms, and if users grants the permissions, follow!
function add_facebook_stream_feed(button) {
  $(button).pulse(true)
  request_extended_perms_common(button, function(resp) {
    $(button).pulse(false)
    if (resp.unconnected) {
      var fbus_box = $("#fb_user_stream_box")
      fbus_box.find("#fb_unconnected").show()
    }
    else {
      var f = resp.feed
      $(button).hide()
//      $("#refresh_fbfeed").show()
      add_follow($('div#my_feeds'), {icon: f.icon, name: f.name, id: f.id, url: f.url, fb_flag: false, twitter_flag: false, mutual_follow_flag: false, dont_refresh_flag: true}) // No refresh of the listing!
      alert("Your Facebook newsfeed has been added and queued for immediate fetch.  You will receive an email after it has been fetched!")
    }
  })

  return false
}

// Pop up the FB extended permissions dialog -- and if we get all we need, great!
// Tell the server to update its permissions and everything should succeed (unless the wily member
// has unlinked their account in the meantime in a separate window! Sneaky ...)

function request_extended_perms() {
  request_extended_perms_common('', function(resp) {
    $('#fb_refresh_perms').hide();
    if (resp.unconnected) {
      alert("Have you unlinked your " + app_name + " account from Facebook?  Please connect and try again!")
      var fbus_box = $("#fb_user_stream_box")
      fbus_box.find("#fb_unconnected").show()
    }
    else {
//      $('#refresh_fbfeed').show();
      alert("Thank you! Try refreshing your feed again now!")
    }
  })
  return false;
}

// 1. Shoot off a request to the server to refresh the news feed
// 2. If we get an error message and we dont have the required extended permissions anymore,
//    display the message that will let the user grant us the necessary permissions!
function refresh_facebook_stream_feed(button) {
  $(button).pulse(true)
  $.ajax({
    url      : '/mynews/refresh_fb_newsfeed',
    type     : 'post',
    data     : {authenticity_token: encodeURIComponent(AUTH_TOKEN) },
    dataType : 'json',
    success  : function(resp) {
      $(button).pulse(false)
      if (resp.error) {
        if (resp.noperms) {
          $("#refresh_fbfeed").hide()
          $("#fb_refresh_perms").show()
        }
        else {
          alert("There was an error fetching your feed. We have logged this error and someone will take a look at this shortly. Feel free to email 'feedback@socialnews.com' with this error report.  Thanks for your understanding!")
        }
      }
      else {
        $('div#my_feeds').find("#refresh_listing_hook").click();
      }
    }
  })

  return false;
}

function invite_friends() {
  FB.ui({method: 'apprequests', message: 'Join NewsTrust',}, requestCallback);
  function requestCallback(response) { }
  return false;
}
