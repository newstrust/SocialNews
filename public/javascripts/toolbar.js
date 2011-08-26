/**
* toolbar.js
*
* Bag of global functions to manage the toolbar popdown forms, including the JS 
* slide animations and the server ajax comm.
*/

// for the benefit of other JS
var in_toolbar = true;
var curr_from_form = null;
var curr_to_form = null;

var form_to_tabs = {
  "info"          : "info",
  "edit"          : "info",
  "review"        : "review",
  "log_in"        : "review",
  "sign_up"       : "review",
  "story_actions" : "review",
  "edit_thanks"   : "info"
}

function isPopupForm() { return $('.popup_form').length > 0; }
function isIE6() { return (jQuery.browser.msie && parseInt(jQuery.browser.version, 10) < 7 && parseInt(jQuery.browser.version, 10) > 4); }
function isIE7() { return (jQuery.browser.msie && parseInt(jQuery.browser.version, 10) == 7); }
var ie6 = isIE6();
var ie7 = isIE7();

/**
* Init Toolbar & forms
* TODO: option to not open _any_ tab on page load
*/
var rtabAnimation;
$(document).ready(function() {
  if (ie7) {
    $('.notice').hide(); // This is required for ie7 because otherwise all notices show up by default on the edit form -- not sure why.
    $('.not_loggedin_notice p.notice').show();
  }

	var default_form = $.query.get('go');
  if (!default_form && $.query.get("popup")) default_form="review";

  if (default_form) {
	  show_popdown_form(default_form);
	  $('#popdown_form').css({'background': 'url(/images/ui/toolbar/bg_form_bottom.png) no-repeat scroll center bottom transparent'});
  }
  else {
    rtabAnimation = setTimeout(function() {
      $('#nav_review').animate({backgroundColor:'#eaeaea'},700,function() { $('#nav_review').removeClass("review_tab_fade").css("background-color", "")}) 
    }, 10000);
  }
	
	// if we're in the popup, make sure outgoing links have expand=true query param
  $('.popup_form a.outbound').each(function() { // all links marked as outbound
	  // This method will prob break if href already has query params; but prob doesn't; ?!
    $(this).attr('href', $(this).attr('href') + "?expand=true");
	});

	var $edit_form_version_menu = $('select#member_preferred_edit_form_version');
	$edit_form_version_menu.change(function() { set_edit_form_version(180); });
	set_edit_form_version(1);
});

function get_edit_form_versions(menu) {
  var form_versions = new Array();
  menu.find('option').each(function(index) { form_versions.push($(this).val()); });
  return $(form_versions);
}

function set_edit_form_version(speed) {
	var $form_version_menu = $('select#member_preferred_edit_form_version');
  var $form_version_options = get_edit_form_versions($form_version_menu);
  var form_version = $form_version_menu.val();
    // var form_version_index = $form_version_options.index(form_version);
    // SSS: This line above isn't working anymore in jquery 1.4.2 .. 
    // Hence the explicit test below! What a waste!
  var form_version_index = -1 
  $form_version_options.each(function(index) { if ($form_version_options[index] == form_version) form_version_index = index });
  $form_fields = $('div.form_field');
	$form_version_options.each(function(index) {
	  var $version_form_fields = $form_fields.filter("." + this);
	  if (form_version_index >= index) $version_form_fields.show();
	  else $version_form_fields.hide();
	});

  // Hide/show special condensed story type field
  if (form_version_index < 2) $('#condensed_story_type_field').show()
  else $('#condensed_story_type_field').hide()

  limit_form_height();
}

function set_form_transition(from, to) { curr_from_form = from; curr_to_form = to; }
function clear_form_transition(from, to) { curr_from_form = null; curr_to_form = null; }

/**
* Callback from all ajax forms (review, edit, login)
* FIXME: no alerts!
*/
function toolbar_form_response(resp, error) {
  reactivateSubmit($('#'+current_form_id()));

    // 1. Force reload form if requested
  if (resp.force_form_reload) {
    // SSS FIXME: Important to unescape so that NYT urls don't break out of the toolbar
    // I think NYT looks for its url in the window location (but why?) and it is sensitive to an exact match.
    // So, we are just piggybacking on NYT's own toolbar with this hack!
    window.location = unescape(window.location.pathname + $.query.set('go', resp.form_transition.to));
  }
  else if (resp.go && !error) {
    // 1. Process state transitions!
    // 2. If we don't already have a place to goto, goto the form passed in: resp.go
    if (resp.form_transition) set_form_transition(resp.form_transition.from, resp.form_transition.to);
    var next_form = curr_to_form;
    if (next_form == null) next_form = resp.go;

    // 3. Process response
    if (resp.delayed_form_reload) setup_delayed_form_reload(resp.delayed_form_reload, resp.reload_target);
    $('#'+current_form_id()+' p.error').html('').hide() // clear out any past errors before switching forms!
// SSS: The state transition code needs to be redone ... not working well yet ... so deferring to post launch
//    switch_popdown_form(next_form, resp.with_message);
    switch_popdown_form(resp.go, resp.with_message);
    if (resp.notice && (resp.notice.length > 0)) $('#'+current_form_id()+' p.notice').html(resp.notice).show(); // display notice if any!
    else $('#'+current_form_id()+' p.notice').hide()
    if (resp.fb_stream_story) fb_publish_to_user_stream(resp.fb_stream_story);  // Publish to fb last!

    // 4. Clear curr from/to after processing it.
    clear_form_transition();
    limit_form_height();
  } else {
    if (resp.error_message) {
      $('#'+current_form_id()+' p.error').html(resp.error_message).show();
    }
    else {
      $('#'+current_form_id()+' p.error').html("Your browser has an expired/invalid session token.  Please reload the toolbar to continue!").show();
      $all_ratings.parents('form').find('.save_button').hide();
    }
    limit_form_height();
  }
}

/**
* If form runs longer than window, make sure there's a scrollbar
* so it isn't just brutally truncated.
*
* This fn should be called after ANY JS which modifies the height of
* ANYTHING in a tab... It can be passed in as a callback to
* the jQuery slide methods.
*/
function limit_form_height(scroll_to_bottom) {
  var is_popup_version = isPopupForm();
  var curr_form_id = current_form_id();
  var $form = $('#'+curr_form_id);
  var is_review_form = (curr_form_id == "review_form");
  var is_edit_form = (curr_form_id == "edit_form");

  // find the variable height portion
  var $vhd = $form.find('.longform:visible');
  var $vhd_container = $form.find('.longform_window:visible');

  function update_height(jquery_selector, correction) {
    var elt = $form.find(jquery_selector);
    if (elt && elt.is(':visible')) available_height = available_height - elt.height() - correction;
  }

  if ($form.is(':visible')) {
    // Clear the resize handler
    $(window).unbind('resize');

    // BLACK MAGIC! magic coefficient I don't quite understand (form vertical padding?)
    // The values here keep changing depending on tweaks to the toolbar
    var TOOLBAR_FORM_CHROME_HEIGHT = is_popup_version ? 175 : 85;
    if (is_review_form) TOOLBAR_FORM_CHROME_HEIGHT -= (ie7 ? 10 : 30);
    if (ie7 && !is_popup_version && is_edit_form) TOOLBAR_FORM_CHROME_HEIGHT -= 40;  // Dont ask me why!

    // SSS: In the popup version, the tabs are below the navbar
    var available_height = $(window).height() - TOOLBAR_FORM_CHROME_HEIGHT;

    if (is_popup_version) update_height("#nav", 0);
    update_height(".form_tabs", 0);
    update_height(".form_header", 0);
    update_height(".button_footer", 40); // floating elements within the div -- hence the 40px correction
    update_height(".flash_warning", 0);
    update_height(".flash_error", 0);
    update_height(".flash_notice", 0);
    update_height(".error", 0);
    update_height(".notice", 0);
    update_height("#fetch_metadata_loading", 20); // # magical correction -- not sure why it is required
    update_height("#fetch_metadata_done", 20);    // # magical correction -- not sure why it is required

    var curr_height = $vhd.height();
    if (curr_height > available_height)
      $vhd_container.css({height: available_height, overflowY: 'scroll'});
    else
      $vhd_container.css({overflowY: 'auto', height: 'auto'});

    // scroll to bottom
    if (scroll_to_bottom)
      $vhd_container.scrollTop(curr_height);

    // restore the window resize handler
    $(window).resize(limit_form_height);
  }
}

// capture window resize event
$(window).resize(limit_form_height);

/**
* Toggle the popdown form. TODO: more elegant animations
*/
var POPDOWN_FORM_SHADOW_HEIGHT = 12;
var edit_tab_open = false;
function done_with_edits(close_form) {
  edit_tab_open = false;
}
function show_popdown_form(form_name) {
  var curr_id = current_form_id();

  // In all cases, (a) clear all selected tabs (b) close any currently open form!
	$('a.toolbar_tab').removeClass('selected');
  $('#popdown_form .form').hide();
	$('#popdown_form').css({'background': 'none'});

  // Open/switch/toggle form
  if (form_name != null) {
    if (form_name == 'edit') {
      edit_tab_open = true;
    }
    else if (edit_tab_open && form_name == 'info') {
      // Once you open the edit form, you cannot switch to the info form till you explicitly save / cancel the edit!
      form_name = 'edit';
    }
    else if (form_name == 'review') {
      // Turn off pulsing once you click on the review tab
      clearTimeout(rtabAnimation);
      $('#nav_review').removeClass("review_tab_fade").css("background-color", "")
    }

    var form_id = form_name+ "_form";
    if (form_id != curr_id) {
      $('#' + form_id).show();
      $('#popdown_form').css({'background': 'url(/images/ui/toolbar/bg_form_bottom.png) no-repeat scroll center bottom transparent'});
      $('#nav_'+form_to_tabs[form_name]).addClass("selected");
      limit_form_height();
    }
  }
}

/**
* Switch from one form to another. TODO: animations, elegance
*/
function switch_popdown_form(form_name, with_message, notice) {
  var $form = $('#'+form_name+'_form');
	$('#popdown_form .form').hide();
	$form.show();

  // Show the 'thanks for your review' msg in the current form only if we have come here after reviewing a story.
  var thanks = $form.find('.review_thanks');
  thanks && (curr_from_form == 'review') ? thanks.show() : thanks.hide();

	// switch on special messaging
  if (notice && (notice.length > 0)) $('#notice').html(notice).show() 
  else $('#notice').html('').hide()

	$form.find('.error_message').hide();
	if (with_message) $form.find('.'+with_message).show();
	
	limit_form_height();
}

/**
* If a form is open, return its id
*/
function current_form_id() {
  return $(".form:visible").length > 0 ? $(".form:visible").get(0).id : null;
}

/**
* Send the user onto the 3rd party site (or just close if we're in the popup)
*/
function close_toolbar() {
	if ($('.popup_form').length > 0) window.close();
	else this.location = story_url;
}

/**
* Because we load all the form HTML at page load time, and don't fetch fresh HTML
* via AJAX after potentially state-changing operations (like login or review POST),
* after one of these operations, we have to force reload of the whole toolbar,
* spring-loaded to the desired tab.
* Not incredibly elegant, but not so bad either.
*/
function setup_delayed_form_reload(forms, target) {
  if (forms.length > 0 && forms[0] == "all") {
    $('a.toolbar_tab').attr('onclick', '').unbind("click").click(function() {
      window.location = target
      return false;
    });
    $('a.save_link').attr('onclick', '').unbind("click").click(function() {
      window.location = target
      return false;
    });
  }
  else {
    $(forms).each(function(i, form) {
      $('a.'+form+'_link').attr('onclick', '').unbind("click").click(function() {
        window.location = (typeof(target) == 'undefined') ? window.location.pathname + $.query.set('go', form) : target
        return false;
      });
    });
  }
}

$('#nav a.toolbar_tab').click(function() {
	this.blur();
})
