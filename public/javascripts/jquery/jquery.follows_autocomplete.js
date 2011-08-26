/**
* follows_autocomplete plugin
*/

/**
* Just instantiate an autocomplete for each matching div
*/
jQuery.fn.follows_autocomplete = function(follower_id, follow_type, current_follows, taxonomy, query_url, listing_refresh_fn, listing_filter_fn) {
  return this.each(function() {
		new $.FollowsAutocomplete(this, follower_id, follow_type, taxonomy, query_url, current_follows, listing_refresh_fn, listing_filter_fn);
	});
};

/**
* FollowsAutocomplete 'class'
*/
jQuery.FollowsAutocomplete = function(div, follower_id, follow_type, taxonomy, query_url, current_follows, listing_refresh_fn, listing_filter_fn) {
  var $selections = $(div).find('ul.selections')
  var $input = $(div).find('input')
  var $addingMsg = $(div).find('#adding_msg')

  var initialized = false
  init();
  initialized = true
  
  // lookup to see if this name is in our taxonomy
  function followed_item_from_name(name) {
    var assoc = null;
    jQuery.each(taxonomy, function() { if (this.name == name) assoc = this; });
    return assoc;
  }

  // DOM builder for new association entries.
  function add_selection(item) {
    // Clear out any active follow filters!
    clear_active_follow_filters();

    var div = jQuery.create('div', {'id': follow_type + '_' + item.id }, '');
    if (item.icon) {
      var img_attrs = {
        'class' : (follow_type == 'feed' || follow_type == 'source') ? 'favicon' : 'favicon18',
        'style' : 'background-image:url(' + item.icon + ');'
      }
      div.append(jQuery.create('span', img_attrs, ''));
    }
    if (follow_type == 'member') {
      if (item.visible_profile) {
        div.append('<span class="item"><a href="' + item.url + '" title="View ' + item.name + '\'s profile">' + item.name + '</a></span>');
      } else {
        div.append('<span class="item">' + item.name + '</span>');
      }
    } else {
      div.append('<span class="item"><a href="' + item.url + '" title="View ' + item.name + '\'s page">' + item.name + '</a></span>');
    }
 
    if ((typeof(item.fb_flag) != 'undefined') && item.fb_flag) {
      var img_attrs = {
        'class' : 'fb_favicon',
        'title' : 'You and ' + item.name + ' are Facebook friends.'

      }
      div.append(jQuery.create('span', img_attrs, ''));
    }

    if ((typeof(item.twitter_flag) != 'undefined') && item.twitter_flag) {
      var img_attrs = {
        'class' : 't_favicon',
        'title' : 'You follow ' + item.name + ' on Twitter.'

      }
      div.append(jQuery.create('span', img_attrs, ''));
    }

    if (item.mutual_follow_flag) {  // mutual follow icon
      var img_attrs = { 
        'class' : 'mutual_follow',
        'title' : 'You and ' + item.name + ' are following each other.'
      }
      div.append(jQuery.create('span', img_attrs, ''));
    }

    var selection = jQuery.create('li', {'class': 'in_taxonomy' + (listing_filter_fn ? ' selectable': '') + (initialized ? ' new' : '')}, div);
    var del       = jQuery.create('span', {'class': 'unfollow', 'title': 'Click to unfollow'});
    div.append(del);
    del.click(function(e) { remove_item_and_refresh(item.id, selection); e.stopPropagation(); });
    make_clickable(selection, follow_type, item.id)

    $selections.append(selection)
  }

  function make_clickable(li, item_type, item_id) {
    if (listing_filter_fn) {
      $(li).unbind('click').click(function() { set_follow_filter(this) });
      $(li).find('a').click(function(e) { e.stopPropagation() });
    }
  }

  function set_follow_filter(button) {
    clear_active_follow_filters();

    // Highlight the button and update the click callback to refresh the entire listing
    $(button).removeClass('selectable').addClass('selected');
    $(button).unbind('click').click(function() { clear_follow_filter(button); listing_filter_fn('') });

    // Now, narrow down the list with the clicked followed item
    var params = $(button).find('div').attr('id').split('_')
    listing_filter_fn(params[0], params[1]);
  }

  function clear_follow_filter(button) {
    $(button).removeClass('selected').addClass('selectable')
    make_clickable(button)
  }

  function clear_active_follow_filters() {
    // FIXME: IMPORTANT: NOTE that this is clearing out clicked follows from ALL panels
    // that are on the page that this is embedded in.  Is there a way of making this
    // more localized while also leaving open the possibility of affecting other panels
    // through hooks that are explicitly passed in?  Punt on this for now ...
    var curr_sel = $('.selected')
    if (curr_sel) clear_follow_filter(curr_sel)
  }

  function remove_item_and_refresh(item_id, selection) {
    // Clear out any active follow_filters!
    clear_active_follow_filters();

    var name = selection.find("span.item a").html();
    selection.html("<span>Removing ...</span>");
    selection.pulse(true, '', true);
    params = {authenticity_token: encodeURIComponent(AUTH_TOKEN), followable_type: follow_type, followable_id: item_id}
    if (follower_id) params["follower_id"] = follower_id
    $.ajax({
      url      : '/mynews/follow_item.js',
      type     : 'post', 
      dataType : 'json',
      data     : params,
      success  : function(resp) {
        if (resp.success) {
          if (follow_type == 'member') {
            // 1. Hide the fb follow notice if it is visible -- this could be a notice about no fb friends around to add
            //    Since we've removed a member, we might have a fb friend to add
            // 2. Close the form since available fb friends might have changed
            $("#fb_friends_notice").html('').hide() 
            $(".fb_error_msg").hide() 
            fb_close_follow_friends_form()
          }
          else if (follow_type == 'feed') {
            if (name.match(/Facebook feed/)) $(".facebook_feed").show();
            else if (name.match(/Twitter feed/)) $(".twitter_feed").show();
          }
          selection.remove();
          if (listing_refresh_fn) listing_refresh_fn();
        }
        else {
          alert(resp.error);
        }
      }
    });
  }

  function has_selection(name) {
    /* SSS FIXME: Incorrect! */
    var has_selection = false;
    $selections.find("li:visible div").each(function() {
      has_selection |= ($(this).text() == name);
    });
    return has_selection;
  }

  function get_selection_from_taxonomy(name) {
    // if not in taxonomy, don't accept it!
    if (taxonomy && !has_selection(name)) {
      var e = followed_item_from_name(name);
      if (e != null)
        return e;
      else
        return null;
    }
    else {
      return 'duplicate';
    }
  }

  function add_followed_item_and_refresh(item) {
    $input.hide()
    $addingMsg.html("Adding " + item.name + "...").show().pulse(true, '', true)
    params = {authenticity_token: encodeURIComponent(AUTH_TOKEN), followable_type: follow_type, followable_id: item.id}
    if (follower_id) params["follower_id"] = follower_id
    $.ajax({
      url      : '/mynews/follow_item.js',
      type     : 'post', 
      dataType : 'json',
      data     : params,
      success  : function(resp) {
        $addingMsg.pulse(false).hide()
        $input.show()
        if (resp.success) {
          add_selection(item);
          if (listing_refresh_fn) listing_refresh_fn();
        }
        else {
          alert(resp.error);
        }
      },
      error : function(resp) {
        $addingMsg.pulse(false).hide()
        $input.show()
        alert("Sorry!  The request didn't go through.  Please try again!")
      }
    });
  }

  function add_item_from_popup(btn) {
    var b = $(btn)
    var args = b.attr("href").split("|")
    add_selection({icon: args[0], name: args[1], id: args[2], url: args[3], fb_flag: args[4] == "true", twitter_flag: args[5] == "true", mutual_follow_flag: args[6] == "true"})
    // Refresh unless we've been asked not to refresh!
    if (((typeof(args[7]) == 'undefined') || (args[7] != "true")) && listing_refresh_fn) listing_refresh_fn();
  }

  function remove_item_from_popup(btn) {
    var b = $(btn)
    var args = b.attr("href").split("|")
    $selections.find('div#'+args[0]+'_'+args[1]).parent().remove()
    if (listing_refresh_fn) listing_refresh_fn();
  }

  function init() {
    // populate selections
    jQuery.each(current_follows, function() { add_selection(this) } );

    // Add handlers for external hooks
    $(div).find('#add_item_hook').click(function() { add_item_from_popup(this); return false; });
    $(div).find('#remove_item_hook').click(function() { remove_item_from_popup(this); return false; });
    $(div).find('#refresh_listing_hook').click(function() { if (listing_refresh_fn) listing_refresh_fn(); return false; });
    $(div).find('#clear_follow_filters_hook').click(function() { clear_active_follow_filters(); return false; });

    // turn rich hashes into flat array
    if (taxonomy) {
      var taxonomy_names = [];
      jQuery.each(taxonomy, function() {
        taxonomy_names.push(this.name);
      });

      // set up autcomplete with result callback
      $input.autocomplete(taxonomy_names, {matchContains: true, resultsClass: "mynews_ac_results", scroll: true, dataType: 'json', alwaysTriggerResult: true})
        .result(function(event, data, formatted) {
          var name = typeof(data) == 'string' ? data : data[0];
          var new_item = get_selection_from_taxonomy(name);
          $(this).val("");
          if (new_item == 'duplicate')
            alert('You are already following ' + name);
          else if (new_item)
            add_followed_item_and_refresh(new_item);
        });
    }
    else {
      $input.autocomplete(query_url, {matchContains: true, resultsClass: "mynews_ac_results", scroll: true, dataType: 'json', alwaysTriggerResult: true})
        .result(function(event, data, formatted) {
          $(this).val("");
          if (typeof(data) != 'string') {
            var new_item = { name               : data[0],
                             id                 : data[1],
                             icon               : data[2],
                             url                : data[3],
                             fb_flag            : data[4] == 'true', 
                             twitter_flag       : data[5] == 'true', 
                             mutual_follow_flag : data[6] == 'true' }
            if (new_item.id) {
              if (has_selection(new_item.name))
                alert('You are already following ' + data[0]);
              else
                add_followed_item_and_refresh(new_item);
            }
          }
        });
    }
  }
};
