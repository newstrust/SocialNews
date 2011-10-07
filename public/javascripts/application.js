/**
* SocialNews general JS
*/

// Variables whose values are set in _story_listing_js_includes.html.erb
var is_story_listing = false;
var member_is_active_reviewer = false;
var cached_stories_state = [];

// switch on one-click meta reviews
$(document).ready(function() {
	$('.meta_review_input .rating_input').rating_input({submit_on_click: true, disable_overall_rating: true});
  $(".tooltipped_icon").tooltip({offset: [2, -8],position: "center left", relative: true}); // Configure tooltips! More at http://flowplayer.org/tools/tooltip/index.html
  if ((jQuery.browser.msie && parseInt(jQuery.browser.version, 10) == 7) && ($('.popup_form').length > 0)) {
    $(".tooltipped_icon_label").tooltip({offset: [-40, -8],position: "center left", relative: true});  //  for main label questions
    $(".tooltipped_icon_popular").tooltip({offset: [-35, -8],position: "center left", relative: true});  //  for 'popular' label questions
  }
  else {
    $(".tooltipped_icon_label").tooltip({offset: [11, -8],position: "center left", relative: true});	//	for main label questions
    $(".tooltipped_icon_popular").tooltip({offset: [5, -8],position: "center left", relative: true});	//	for 'popular' label questions
  }
});

$(document).ready(function() {
  // $('.main_column_box').supersleight({shim: '/images/ui/spacer.gif'}); // IE6 PNG fix.
  // $(document).pngFix(); // IE6 PNG fix. doesn't treat background images very nicely, commenting out!
});

function rotate_badges() {
// Set up the appropriate badge to show based on visitor!  
  var badge_div = $('.rotating_badge_div');
  if (badge_div.length > 0) {
    var badge_image_urls;
    var badge_target_urls;
    if (!member_is_logged_in) {
        // Guest
      badge_image_urls = typeof(guest_badge_image_urls) == "undefined" ? [] : guest_badge_image_urls;
      badge_target_urls = typeof(guest_badge_target_urls) == "undefined" ? [] : guest_badge_target_urls;
    }
    else if (!member_is_active_reviewer) {
        // Logged in member who is not an active reviewer
      badge_image_urls = typeof(member_badge_image_urls) == "undefined" ? [] : member_badge_image_urls;
      badge_target_urls = typeof(member_badge_target_urls) == "undefined" ? [] : member_badge_target_urls;
    }
    else {
        // Logged in member who is an active reviewer
      badge_image_urls = typeof(active_member_badge_image_urls) == "undefined" ? [] : active_member_badge_image_urls;
      badge_target_urls = typeof(active_member_badge_target_urls) == "undefined" ? [] : active_member_badge_target_urls;
    }

    var num_badges = badge_image_urls.length;
    badge_div.each(function(i) {
      var rand = Math.ceil(Math.random()*num_badges);
      $(this).find("img").attr('src', badge_image_urls[rand-1]);
      $(this).find("a").attr('href', badge_target_urls[rand-1]);
    });
  }
}

function patch_cached_stories() {
  // All this js code should be factored out into a function that triggers only
  // for story listings or story overview pages.  So, for now, we are backing out
  // if is_story_listing is undefined!
  if ((typeof(is_story_listing) == "undefined") || !is_story_listing)
    return;

  if (member_is_editor) $('.story_edit_link').show();
  if (member_is_editor) $('.edit_link').show().attr("title","Edit this story");

  if (cached_stories_state) {
    $.each(cached_stories_state, function(id, state) {
      var $story_links = $('div.story_links[story_id='+id+']');
      // NOTE: copy changes on the next line must be made in ReviewsHelper#link_to_new_review as well!!!
      if (state.reviewed) $story_links.find('a.review_link').addClass('on').attr("title","Edit your review");
      // NOTE: copy changes on the next line must be made in StoriesHelper#link_to_star as well!!!
      if (state.saved) toggle_star_display(id, true, "Click here to unstar this story");
    });
  }
}

/**
* Apply proper styles/handlers to story links on cached pages,
* where we can't just burn this user-specific logic into the cached HTML fragment.
*/
$(document).ready(function() {
  rotate_badges()
  patch_cached_stories()
});

// Automatically insert the authtoken to outgoing requests
$(document).ajaxSend(function(event, request, settings) {
  if (typeof(AUTH_TOKEN) == "undefined"){ return false; }
  // settings.data is a serialized string like "foo=bar&baz=boink" (or null)
  settings.data = settings.data || "";
  settings.data += (settings.data ? "&" : "") + "authenticity_token=" + encodeURIComponent(AUTH_TOKEN);
  return this;
});

function add_textile_support_links() {
    $('.textile_support_link').bind("click.forComments",
    function(event) {
        var p = $(event.target).parent().get(0);
        $(p).next().toggle("fast");
        event.preventDefault();
    });
    $('.close_textile_support_link').bind("click.forComments",
    function(event) {
        var p = $(event.target).parent().get(0);
        while (p.tagName !== 'DIV') {
            p = $(p).parent().get(0);
        }
        $(p).hide();
        event.preventDefault();
    });
}

$(document).ready(function() {
  add_textile_support_links();
});

// Ensure the we can't double click an ajax link and submit it more than once.
function blockAjax(element, callback) {
    if (!$(element).hasClass('in_use')) {
        $(element).addClass('in_use');
        callback();
    }
}

function unblockAjax(element) {
    $(element).removeClass('in_use');
}

/*
  Function: assignFlags
  This method will assign the flaggable actions to any hyperlinks with the .flaggable and .unflaggable classes
*/
function doflag(event, flag_url) {
  var params = {
      flaggable_type: $(event.target).attr('flaggable_type'),
      flaggable_id: $(event.target).attr('flaggable_id'),
      reason: $(event.target).attr('reason')
  };
  blockAjax($(event.target),function(){
      $(event.target).pulse(true);
      $.ajax({
          dataType: 'json',
          type: "POST",
          data: params,
          url: flag_url,
          success: function(data) {
              $("#server_result_" + data.id).html(data.flash.notice);
              $(event.target).unbind('click');
              $(event.target).bind('click', function(e){ undoflag(e, flag_url); });
              updateComment(data.flaggable);
              update_flag_trigger($(event.target).attr('reason'), event.target, false);
          },
          complete: function(data) {
            unblockAjax($(event.target));
            $(event.target).pulse(false);
          }
      });
  });

  event.preventDefault();
}

function undoflag(event, flag_url) {
  var params = {
      _method: 'delete',
      flaggable_type: $(event.target).attr('flaggable_type'),
      reason: $(event.target).attr('reason')
  };
  blockAjax($(event.target),function(){
      $(event.target).pulse(true);
      $.ajax({
          dataType: 'json',
          type: "POST",
          data: params,
          url: "/flags/" + $(event.target).attr('flaggable_id') + '.json',
          success: function(data) {
              update_flag_trigger($(event.target).attr('reason'), event.target, true);
              $("#server_result_" + data.id).html(data.flash.notice);
              $(event.target).unbind('click');
              $(event.target).bind('click', function(e){ doflag(e, flag_url); });
              updateComment(data.flaggable);
          },
          complete: function(data) {
            $(event.target).pulse(false);
            unblockAjax($(event.target));
          }
      })
  });

  event.preventDefault();
}

function update_flag_trigger(reason, e, flaggable) {
    switch (reason) {
    case 'flag':
        $(e).text((flaggable) ? "Flag" : "Unflag");
        break;
    case 'like':
        $(e).text((flaggable) ? "Like" : "Unlike");
        break;
    }
    if (flaggable) {
        $(e).removeClass('unflaggable');
        $(e).addClass('flaggable');
    } else {
        $(e).removeClass('flaggable');
        $(e).addClass('unflaggable');
    }
}

function assignFlags(flag_url, scope) {
    $(".flaggable").bind('click' + scope, function(event){ doflag(event, flag_url); });
    $(".unflaggable").bind('click' + scope, function(event){ undoflag(event, flag_url); });
}

var send_to_friend_params = { url : '/mailer/send_to_friend/' }
$(document).ready(function() {
  function format_send_to_friend_post(){
    return "message[body]=" + encodeURIComponent($("#message_body").val()) +
           "&message[to]=" + $("#message_to").val() +
           "&message[template]="+send_to_friend_params.template +
           "&message[page]="+send_to_friend_params.page +
           "&message[record_id]="+send_to_friend_params.record_id +
           "&message[from]=" + $("#message_from").val();
  }

  function handle_response(response) {
    if(response.flash) {
        var status_types = ["error", "notice", "warning"];
        for(var x in status_types) {
            if(response.flash[status_types[x]]) {
                var type = status_types[x];
                $("#" + type + "_results").html(response.flash[type]);
                $("#" + type + "_results").show();
                $("#" + type + "_results").click(function () {
                    $(this).fadeOut(1000, function () {
                        $(this).hide();
                    });
                });
            }    
        }   
    }
  }

/*
  $("#email_this_page").bind('click', function () {
      $(this).toggleClassAbsolute('on', (!$('#form_container').is(':visible')));
      var link_pos = $(this).position();
      $('#send_to_friend_form').css({top: link_pos.top + 45, left: link_pos.left});
      $('#send_to_friend_form .wrapper').toggle();
      return false;
  });
*/

  $("#send_to_friend_form_submit").click(function() {
    var sendButton = $(this);
    blockAjax(sendButton, function() {
      $.ajax({
        type: "POST",
        url: send_to_friend_params.url,
        dataType: "json",
        data: format_send_to_friend_post(),
        success: function(msg) {
          handle_response(msg);
          $('#form_container').slideToggle("slow");
          $('#form_results').slideToggle("slow");
          $('#form_results').click(function () {
            $(this).fadeOut(180, function () { $(this).hide(); });
          });
          $('#collapse_all').click(function() {
            $('#form_results').html('');
            $('#form_container').show();
            $('#collapse_all').hide();
            $('#send_to_friend_form .wrapper').hide();
          }).show();
          $('#form_results').html(
            function() {r = "<dl>";
              if(msg.sent.length > 0) {
                r += "<dt>Delivered</dt>";
                r +="<dd>" + msg.sent.join(', ') + "</dd>";
              }
              if(msg.unsent.length > 0) {
                r += "<dt>Unsent</dt>";
                r += "<dd>"+ msg.unsent + "</dd>";
              }
              if(msg.undeliverable.length > 0) {
                r += "<dt>Undeliverable</dt>";
                r += "<dd>" + msg.undeliverable + "</dd>";
              }
              r +="<dl>";
              return r;
	    }()
          );
          unblockAjax(sendButton);
        },
        error: function(msg) {
          switch (msg.status) {
          case 406:
            response = new Function("return " + msg.responseText)();
            handle_response(response);
            break;
          }
        }
      }); // $.ajax
    }); // blockAjax

    return false;
  }); // click handler
});

/**
* Pulse opacity on ajax links to visualize processing
*/
jQuery.fn.pulse = function(go, link_text, hideUpdated) {
  function do_pulse(pulse_link) {
    if (pulse_link.attr('pulsing') == 1) {
      var fade_to = (pulse_link.css('opacity') == 1 ? 0.2 : 1);
      pulse_link.removeClass('updated').fadeTo(600, fade_to, function() {
        // $(this).style.removeAttribute("filter"); // Fix for IE; http://jquery-howto.blogspot.com/2009/02/font-cleartype-problems-with-fadein-and.html
        if (pulse_link.is(':visible')) do_pulse($(this));
        else pulse_link.css('opacity', 1)
      });
    }
    else {
      pulse_link.fadeTo(100, 1, function() {
        //$(this).style.removeAttribute("filter"); // Fix for IE; http://jquery-howto.blogspot.com/2009/02/font-cleartype-problems-with-fadein-and.html
      });
      if (typeof(hideUpdated) == "undefined" || !hideUpdated) pulse_link.addClass('updated');
      if (pulse_link.attr('link_text') != "") pulse_link.html(pulse_link.attr('link_text'));
    }
  }

  if (go) {
    $(this).attr('pulsing', 1);
    do_pulse($(this));
  } 
  else {
    $(this).attr('pulsing', 0);
    if (!link_text) link_text = "";
    $(this).attr('link_text', link_text);
  }
  return $(this);
};

/**
* For fancy NT buttons
* gray out button in UI, submit form, debounce form (disable 2nd submission)
*/
function submit_form_button(button, debounce) {
  $(button).addClass('formButtonProcessing')
  if (debounce) $(button).parents('form').submit().submit(function() {return false});
}

/* There seem to be at least three duplicate debounce solutions in this JS file -- each one created by different developers at different times for different tasks.  Need to consolidate everything into one! */
function reactivateSubmit(form)
{
  $(form).find('.processing_form_msg').html('Successfully saved!').css({'float':'none'}).show().pulse(false);
  $(form).find('.save_button').removeClass('in_use').parents('span').show();
  setTimeout(function() { $(form).find('.processing_form_msg').hide() }, 4000);
}

function deactivateSubmit(button)
{
  if ($(button).hasClass('in_use')) {
    return false;
  }
  else {
    $(button).addClass('in_use');
    $(button).parents('span').hide();
    $(button).parents('.button_footer').find('.processing_form_msg').html('Saving ...').show().pulse(true, "", true);
    return true;
  }
}


/**
* Show/hide parts of reviews on story detail page
*/
function show_review_part(review_part, button) {
  if (review_part) {
    $('div.review_part').not('.'+review_part).slideUp(150).end().filter('.'+review_part).slideDown(150);
  } else {
    $('div.review_part').slideDown(150);
  }
  $('.show_activity_part a').removeClass();
  $(button).addClass('sel');
}

/**
* Show/hide parts of member activity on member page
*/
function show_member_activity(activity, button) {
  if (activity) {
    $('div.member_activity').not('.'+activity).slideUp(150).end().filter('.'+activity).slideDown(150);
  }
  else {
    $('div.post').hide();
    $('div.like').hide();
    $('div.review').hide();
    $('div.all_activity').slideDown(50);
  }
  $('.show_activity_part a').removeClass();
  $(button).addClass('sel');
}

/**
* More Info boxes. apply to whole white bar?
*/
$(document).ready(function() {
  $('.more_info_box .wrapper').click(function(event) {
    $('#more_info').slideToggle(180);
    $(this).find('span').toggleClass('more').toggleClass('less');
  });
});

/**
* Must do tricky slide for Ratings Boxes on detail pages
*/
var RATINGS_BOX_MINIMIZED_HEIGHT = 60;
function slide_ratings_box($more_button, $itemized_holster) {
  var high_tide = $itemized_holster.height() > RATINGS_BOX_MINIMIZED_HEIGHT;
  var tide_marks = $itemized_holster.find('.itemized').map(function(i, div) {return $(div).height()}); // two divs
  var high_tide_mark = Math.max(tide_marks[0], tide_marks[1]); // not pretty, sorry world
  var tide = high_tide ? RATINGS_BOX_MINIMIZED_HEIGHT : high_tide_mark;
  $itemized_holster.animate({height: tide}, 150);
  $more_button.text(high_tide ? 'more' : 'less').toggleClassAbsolute('on', !high_tide);
}

/**
* JavaScript doesn't fire onSubmit event when you call submit() on a form.
* So, trigger it explicitly!  This is so we can use handy jRails helpers like remote_form_for, etc.
*/
var submit_with_onsubmit = function(f) {
  $(f).trigger('onsubmit');
  return false
}

/**
* helper method
*/
jQuery.fn.toggleClassAbsolute = function(className, on) {
  if (on) $(this).addClass(className);
  else $(this).removeClass(className);
  return $(this);
};

/** FIXME: Refactor this code into login.js **/
var hide_fixup_notice = true;
var invitation_id = null;
var partner_id = null;
function fbc_login() {
  fbc_activate((partner_id && invitation_id) ? "/partners/" + partner_id + "/" + invitation_id : "", "")
}

function fbc_activate(url_prefix, url_suffix) {
  if (fb_sandbox_mode) {
    // In sandbox mode, getLoginStatus won't work properly because FB cannot always
    // determine if the visitor has authorization to the sandboxed app or not.
    window.location.href = url_prefix + "/fb_connect/activate" + url_suffix;
  }
  else {
    FB.getLoginStatus(function(resp) {
      if (resp.status == "unknown") { // User clicked cancel
        ;
      } else {
        window.location.href = url_prefix + "/fb_connect/activate" + url_suffix;
      }
    });
  }
}

$(document).ready(function() {
  if (hide_fixup_notice) {
    var n = $('#fixup_notice');
    if (typeof(n) != 'undefined' && n) n.parent().hide()
  }
})

/** FIXME: Refactor this code into starring.js **/
function toggle_star(link, opts) {
  $(link).pulse(true);
  $.ajax({
    url      : '/stories/' + opts.id + '/save.js' + ((typeof(opts.ref) == 'undefined' || opts.ref == '' || opts.ref == null) ? '' : '?ref=' + opts.ref),
    type     : 'post',
    data     : {authenticity_token: encodeURIComponent(AUTH_TOKEN)},
    dataType : 'script',
    complete : function(request) { update_star_link(link, request, opts); }
  })
  return false;
}

function toggle_star_display(story_id, starred, title_text) {
  $("a.save_link[story_id="+story_id+"]").toggleClassAbsolute('on', starred).attr('title', title_text);
}

function update_star_link(save_link, request, opts) {
  var starred = request.responseText == "true"
  var new_link_title = 'Click here to ' + (starred ? 'unstar' : 'star') + ' this story';
  $(save_link).pulse(false);
  toggle_star_display($(save_link).attr("story_id"), starred, new_link_title);
}

/** FIXME: Refactor this code into listings.js or tools.js **/
var emailDialog = null;
function email_item(button, obj) {
  var edc = $('#email_dialog_container');
  edc.show();
  edc.find('#send_to_friend_form .wrapper').show();
  edc.find('#send_to_friend_form .wrapper #form_results').hide();
  edc.find('#send_to_friend_form .wrapper #error_results').hide();
  edc.find('#send_to_friend_form .wrapper #notice_results').hide();
  edc.find('#send_to_friend_form .wrapper #warning_results').hide();
  edc.find('#send_to_friend_form .wrapper #form_container').show();

  if (emailDialog == null) {
    edc.find('#send_to_friend_form #collapse_all').remove();
    emailDialog = edc.dialog({ autoOpen:false, height:340, width:325});
  }

  if (obj.type == 'home' || obj.type == '') {
    email_title = 'Email this page';
    email_heading = 'Send your friends a link to this SocialNews page.';
  } else {
    email_title = 'Email this ' + obj.type;
    email_heading = 'Send your friends a link to this ' + obj.type + '.';
  }

  // Set up the page
  send_to_friend_params.title = email_title;
  send_to_friend_params.page = obj.url;
  send_to_friend_params.record_id = obj.id;
  send_to_friend_params.template = obj.type;
  edc.find('#heading').html(email_heading);
  edc.find('#title').html(obj.title);

  // Position the dialog and display it
  var b = $(button);
  var x = b.position().left - $(document).scrollLeft();
  var y = b.position().top - $(document).scrollTop();
  // For mynews listing, because of css for the button, the 'y' co-ordinate is relative to the containing div elt!
  // So, instead pick the closest 'li' ancestor as the reference element.
  try { if (y < 50) y = b.parents("li").position().top - $(document).scrollTop() } catch(err) {}
  emailDialog.dialog("option", "position", [x,y]);
  emailDialog.dialog("option", "title", email_title);
  emailDialog.dialog("open");
}

function email_page(button, params) {
  if (!params.url) {
    params.url = location.href;
  }
  params.title = '';
  email_item(button, params);
}

function close_email_dialog() {
  emailDialog.dialog("close");
}

var loginDialog = null;
function show_login_dialog() {
  if (loginDialog == null)
    loginDialog = $('#login_dialog_container').dialog({autoOpen:false, modal:true, title:"Please login to continue", height: 'auto', width:375})

  loginDialog.dialog("open");
}
