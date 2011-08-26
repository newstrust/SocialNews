/**
* story_lookup plugin
*
* On Submit Form, run to the server & try to see what we can figure out about the story
* just from the URL.
*/

jQuery.fn.story_lookup = function(custom_params, autopopulate_handler) {
  return this.each(function() {
		new $.StoryLookup(this, custom_params, autopopulate_handler);
	});
};

jQuery.StoryLookup = function(div, custom_params, autopopulate_handler) {
  var AUTOPOPULATE_URL = "/stories.js";
  var PROMPT_STRING = "http://";
  
  var $url_field = $(div).find('input');
  var $status = $(div).find('.status div');
  
  $(div).bind("lookup_url", function(event) {
    lookup_url();
    return $(this);
  });
  
  $url_field.focus(function() {
    if ($(this).val() == PROMPT_STRING) $(this).val('').removeClass('prompt');
    $(this).attr('old_value', $(this).val());
    $status.removeClass().addClass('go');
  }).blur(function() {
    if ($(this).val() == "") {
      $(this).val(PROMPT_STRING).addClass('prompt');
    } else if ($(this).val() == $(this).attr('old_value')) {
      // do nothing
    } else if ($status.hasClass('go')) {
      lookup_url();
    }
  }).keydown(function(e) {
    if (event_is_paste(e)) setTimeout(lookup_url, 5);
    return true;
  }).keypress(function(e) {
    if (e.keyCode == 13) { e.preventDefault(); lookup_url(); }
  });

  if ($url_field.val() == "") $url_field.blur();
  
  $status.click(lookup_url);
  
  function lookup_url(url) {
    if ($status.hasClass('in_use'))
      return;

    $status.removeClass().addClass('in_use loading');

    var url = $url_field.val();
    var params = jQuery.extend(custom_params, {url: url});
    $.post(AUTOPOPULATE_URL, params, function(data) {
      $status.removeClass().addClass((data.error) ? 'error' : 'done');
      if (!data.error) $url_field.val(data.url);
      autopopulate_handler(data, $(div));
    }, "json");
  };
};

/**
* util
*/
function event_is_paste(e) {
  return (String.fromCharCode(e.keyCode).match(/v/i) && (e.ctrlKey || e.metaKey));
};
