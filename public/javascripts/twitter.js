$(document).ready(function() {
  $('textarea[name=tweet]').keyup(function() { limit_tweet($(this)) });
  $("#twitter_follow_friends_link").click(function() { return twitter_populate_friends_form() });
})

function fetch_short_url(url, success_callback) {
  /* SSS FIXME: Why are we querying the NT server and asking it to query bit.ly?  Why not just hit bit.ly directly here? */
  $.ajax({
    url      : '/shorten_url',
    data     : { url: url },
    dataType : 'json',
    timeout  : 10000, // 10 second timeout
    success  : success_callback,
    error    : function(obj, errStatus) {
      if (errStatus == 'timeout') alert('We are sorry!  We cancelled the request since this is taking a long time.  Please close the dialog and try again.')
    }
  })
}

function insert_short_url(short_url) {
  var tweet = $('textarea[name=tweet]').attr('value');
  $('textarea[name=tweet]').attr('value', tweet + ' ' + short_url);
}

var short_url_inserted = false;
function update_tweet_box_with_short_url() {
  var short_url = $('#short_url_value').attr('value');
  if (short_url.length < 30) { // 30 is arbitrary
    insert_short_url(short_url);
  }
  else {
    $('#short_url_msg').show().pulse(true);
    fetch_short_url(short_url, function(resp) {
        var url = resp.url;
        $('#short_url_msg').hide().pulse(false);
        insert_short_url(url);
        $('#short_url_value').attr('value', url)
        limit_tweet($('textarea[name=tweet]'));
      });
  }
}

function limit_tweet(tweet_input) {
  var charLimit  = 140;
  var charLength = $(tweet_input).attr('value').length;
  var form       = $(tweet_input).parents('form'); // closest ancestor which is a form
  var submit_btn = form.find('.save_button') // find the submit button
  $('#tweet_char_counter').html((charLimit - charLength) + ' characters left.');
  if((charLimit - charLength) <= 0 ) {
    var span = $('#tweet_char_counter')
    span.html('<b style="color:red">Please limit your tweet to ' + charLimit + ' characters to tweet.</b>');
    span.siblings().hide()
    submit_btn.hide();
  } else {
    var span = $('#tweet_char_counter')
    span.siblings().show()
    submit_btn.show();
  }
}

function toggle_tweet_box(curr_val, tweet_box, is_toolbar) {
  tweet_box.toggle();
  if (curr_val == 1) {
    tweet_box.parents('form').find('.save_button').show()  // Find the enclosing form, and show its submit button
  }
  else {
    if (!short_url_inserted) {
      update_tweet_box_with_short_url()
      short_url_inserted = true
    }
    limit_tweet($('textarea[name=tweet]'))
  }

  if (is_toolbar) limit_form_height(true);
}

function add_twitter_newsfeed(button) {
  $(button).pulse(true)
  $.ajax({
    url      : '/twitter/follow_newsfeed.js',
    type     : 'post',
    data     : { authenticity_token: encodeURIComponent(AUTH_TOKEN) },
    dataType : 'json',
    success  : function(resp) {
      $(button).pulse(false)
      if (resp.unconnected) {
        $("#twitter_unconnected").show()
      }
      else {
        var f = resp.feed
        $(button).hide()
        add_follow($('div#my_feeds'), {icon: f.icon, name: f.name, id: f.id, url: f.url, fb_flag: false, twitter_flag: false, mutual_follow_flag: false, dont_refresh_flag: true}) // No refresh of the listing!
        alert("Your Twitter newsfeed has been added and queued for immediate fetch.  You will receive an email after it has been fetched!")
      }
    }
  })

  return false
}

function twitter_close_follow_friends_form() {
  // Remove all followable friend elements we added
  $("#twitter_followable_friends").children().remove()

  // Hide the form
  var form = $("#twitter_friends_form")
  form.hide()
  form.parent().hide()

  // Reset the click event handler
  $("#twitter_follow_friends_link").unbind("click").click(function() { return twitter_populate_friends_form() })

  return false;
}

function twitter_populate_friends_form() {
  var follow_link = $("#twitter_follow_friends_link")
  $("#twitter_friends_notice").html('').hide() 
  $(".twitter_error_msg").hide()
  follow_link.pulse(true, '', true)
  $.ajax({
    url      : '/twitter/followable_friends.js',
    type     : 'get',
    dataType : 'json',
    timeout  : 15000, // 15 second timeout
    success  : function(resp) {
      follow_link.pulse(false, '', true)
      follow_link.unbind("click").click(function() { return twitter_close_follow_friends_form() })
      var f_box = $("#twitter_friends_box")
      f_box.show()
      if (resp.error != null) {
        f_box.find("#" + resp.error).show()
      }
      else {
        $("#twitter_friends_form").show()
        var container_div = $("#twitter_followable_friends")
        for (var i = 0; i < resp.members.length; i++) {
          var elt = resp.members[i]
          var div = $.create('div', {'class': 'friend_row'}, '')
          // This doesn't work in IE7/IE8 .. hence using a html string below
          // div.append($.create('input', {'type': 'checkbox', 'name': 'follow_ids[' + elt.id + ']', 'value': 1, 'checked': 'checked', 'class': 'check', 'style': 'float:left'}, ''))
          div.append($('<input type="checkbox" name="follow_ids[' + elt.id + ']" value="1" checked="checked" class="check" style="float:left" />'));
          var span = $.create('span', '', '');
          if (elt.icon) {
            var img_attrs = { 'class': 'small_thumb', 'style': 'background-image:url(' + elt.icon + ');' }
            span.append(jQuery.create('span', img_attrs, ''));
          }
          span.append(elt.name)
          div.append(span)
          container_div.append(div)
        }
      }
    },
    error : function(obj, errStatus) {
      follow_link.pulse(false, '', true)
      if (errStatus == 'timeout') alert('We are sorry!  Looks like SocialNews or Twitter servers are loaded. Please try again in a little while.')
    }
  })

  return false;
}

function twitter_follow_friends() {
  var form = $("#twitter_friends_form")
  var form_data = form.serialize()
  var notice = $("#twitter_friends_notice")
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
      twitter_close_follow_friends_form()

      // Refresh listing
      container.find("#refresh_listing_hook").click();
    }
  })
  return false;
}

// These two functions below are used to support the tweet icon in story listings
function update_tweetbox(tweet_text, short_url) {
  var tdc = $('#tweet_dialog_container');
  tdc.find('#short_url_value').attr('value', short_url);
  tdc.find('textarea[name=tweet]').attr('value', tweet_text);
  limit_tweet(tdc.find('textarea[name=tweet]'));
}

var $tweetDialog = null;

function setup_tweet_dialog(button, title) {
  if ($tweetDialog == null) {
    $tweetDialog = $('#tweet_dialog_container').dialog({autoOpen:false, modal:false, title:title, height: 'auto', width:345})
    $("#tweet_dialog_container #tweet_box").show()
    $("#tweet_dialog_container #tweet_char_counter").show()
  }

  // Clear tweet box, hide tweet status, and show form!
  $('#tweet_dialog_container textarea[name=tweet]').attr('value', '');
  $("#tweet_dialog_container #tweet_status").hide();
  $("#tweet_dialog_container form").show();

  // Position the dialog
  var b = $(button);
  var x = b.position().left - $(document).scrollLeft();
  var y = b.position().top - $(document).scrollTop();
  // For mynews listing, because of css for the button, the 'y' co-ordinate is relative to the containing div elt!
  // So, instead pick the closest 'li' ancestor as the reference element.
  try { if (y < 50) y = b.parents("li").position().top - $(document).scrollTop() } catch(err) {}
  $tweetDialog.dialog("option", "position", [x,y]);
  $tweetDialog.dialog("option", "title", title);
  $tweetDialog.dialog("open");
}

function tweet_page(button, page_info) {
  setup_tweet_dialog(button, 'Share this page on Twitter');
  fetch_short_url(page_info.url, function(resp) {
    $('#short_url_msg').hide().pulse(false);
    update_tweetbox(page_info.tweet_text + " " + resp.url, resp.url); 
  })
}

function tweet_story(button, story) {
  setup_tweet_dialog(button, 'Share this story on Twitter');

  // Insert/fetch the short url into the tweet box
  var n = story.short_url.length; 
  if (n > 0 && n < 30) { // 30 is arbitrary
    update_tweetbox("Check out '" + story.title + "' " + story.short_url + " on @SocialNews", story.short_url);
  }
  else {
    $('#short_url_msg').show().pulse(true);
    fetch_short_url(story.url, function(resp) {
      $('#short_url_msg').hide().pulse(false);
      update_tweetbox("Check out '" + story.title + "' " + resp.url + " on @SocialNews", resp.url);

      // Update the short url in the backend so we dont hit bit.ly repeatedly
      $.post("/stories/" + story.id + "/short_url", {url: resp.url})
    })
  }
}

function close_tweet_dialog() {
  $tweetDialog.dialog("close");
}

function tweet_status(resp) {
  if (resp.error) {
    $("#tweet_dialog_container #tweet_status").html(resp.error).show();
  }
  else {
    $("#tweet_dialog_container #tweet_status").html(resp.notice).show();
  }
  $("#tweet_dialog_container form").hide();
}
