function add_follow(container, item) { 
  var arg_str = item.icon + "|" + item.name + "|" + item.id + "|" + item.url + "|" + item.fb_flag + "|" + item.twitter_flag + "|" + item.mutual_follow_flag + "|" + item.dont_refresh_flag;
  container.find("#add_item_hook").attr("href", arg_str).click();
}

function remove_follow(container, item_type, item_id) {
  var arg_str = item_type + "|" + item_id;
  container.find("#remove_item_hook").attr("href", arg_str).click();
}

function toggle_follow_common(button, member_id, item_type, item_id, success_callback) {
  if (button) $(button).pulse(true, '', true);
  params = {followable_type: item_type, followable_id: item_id, authenticity_token: encodeURIComponent(AUTH_TOKEN)}
  if (member_id) params["follower_id"] = member_id
  $.ajax({
    url      : '/mynews/follow_item.js',
    type     : 'post', 
    dataType : 'json',
    data     : params,
    timeout  : 15000, // 15 second timeout
    success  : function(resp) { 
      if (button) $(button).pulse(false, '', true);
      success_callback(resp) 
    },
    error    : function(obj, errStatus) {
      if (button) $(button).pulse(false, '', true);
      if (errStatus == 'timeout') alert('We are sorry! Looks like the server is busy. Please wait for about 30 seconds and try again.')
    }
  });
}

function common_success_callback(resp, is_popup, button, item) {
  if (resp.success) {
    var b = $(button)
    var cls = b.attr('class');
    if (cls.match(/^follow/)) b.attr('class', cls.replace("follow", "unfollow"));
    else if (cls.match(/^unfollow/)) b.attr('class', cls.replace("unfollow", "follow"));

    var tip = b.attr('title');
    if (tip) {
      if (tip.match(/Follow/)) b.attr('title', tip.replace("Follow", "Unfollow"));
      else if (tip.match(/Unfollow/)) b.attr('title', tip.replace("Unfollow", "Follow"));
    }

    if ((typeof(item.refresh_panel) != 'undefined') && item.refresh_panel) {
      var jq_scope  = is_popup ? window.opener : window
      var container = jq_scope.$('div#my_' + item.type + 's')
      if (resp.created)
        add_follow(container, item);
      else
        remove_follow(container, item.type, item.id);
    }
  }
}

function popup_parent_toggle_follow(button, buttonDiv, member_id, item)  {
  item.refresh_panel = true
  toggle_follow_common(buttonDiv, member_id, item.type, item.id, function(resp) { common_success_callback(resp, true, button, item); });
  return false;
}

function toggle_follow(button, item) {
  toggle_follow_common(button, null, item.type, item.id, function(resp) { common_success_callback(resp, false, button, item); });
  return false;
}
