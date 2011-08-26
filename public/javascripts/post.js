/**
* "Post a Story" form: submit on paste, display status, etc.
*
* A lot of this is redundant with jquery.story_lookup.js, so they should perhaps be combined.
*/

var PROMPT_STRING = "http://";

$(document).ready(function() {
  var $status = $('#post_story .status div');

  function post_story() {
    if ($status.hasClass('in_use'))
      return;

    $status.removeClass().addClass('in_use loading');
    submit_with_onsubmit($('#post_story form'));
  }

  $('#post_story input[name=url]').keydown(function(e) {
    if (event_is_paste(e)) setTimeout(post_story, 5);
  }).keypress(function(e) {
    if (e.keyCode == 13) { e.preventDefault(); post_story(); }
  }).focus(function(e) {
    if ($(this).val() == PROMPT_STRING) $(this).val('').removeClass('prompt');
  }).blur(function(e) {
    if ($(this).val() == '') $(this).val(PROMPT_STRING).addClass('prompt');
  }).blur();
  
  $status.click(post_story);
});

/**
* Server reponse after Post Story (= 'autopopulate')
*/
function post_story_response(request, error) {
  if (!request.error && !request.validation_errors.length) {
    this.location = request.toolbar_path;
  } else {
      // We COULD sift through all error messages & display them.
      // var error_message = $.map(request.validation_errors, function(message_parts, i) { return message_parts.join(" ") }).join("<br/>");
      // just use this message, since that's the only field on the form!
    if (request.validation_errors.length) {
      var error_message = request.validation_errors; //"INVALID URL (email help@socialnews.com if incorrect)";
      $('#post_story input').css({'background-color': '#ffc'});
      $('#post_story').siblings('div.flash_error').html(error_message).show();
      $('#post_story').hide();
    }
    $('#post_story .status div').removeClass().addClass('post');
  }
}
