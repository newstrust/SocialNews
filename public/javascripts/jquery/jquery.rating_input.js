/**
* rating_input plugin
*
* Display rollover stars for review form & ultimately one-click reviews as well
*/

function process_overall_rating() 
{
  var $overall_rating = $('#overall_rating div');
  if ($overall_rating.length > 0) { // make sure this is only called if $overall_rating is there...
    var $all_ratings = $('#overall_rating div');
    var OVERALL_RATING_URL = "/reviews/overall_rating";
    $overall_trustometer_bar = $overall_rating.find('.trustometer * .bar div');
    var serialized_form = $all_ratings.parents('form').serialize();
    $overall_trustometer_bar.addClass('loading');
    // note: for some reason, this MUST be a post for IE6; get triggers bizarre JS error.
    $.ajax({
      url      : OVERALL_RATING_URL,
      type     : 'post',
      data     : serialized_form,
      dataType : 'json',
      success  : function(data) {
        if (typeof(data) == 'undefined' || data == null || typeof(data.rating) == 'undefined') {
          $all_ratings.parents('.shadow').find('.error').html("Your browser has an expired/invalid session token.  Please reload the toolbar/popup to continue!").show();
          $all_ratings.parents('form').find('.save_button').hide();
          $all_ratings.parents('form').find('.longform_window').hide();
        }
        else {
          $overall_trustometer_bar.animate({'width': data.percent + '%'}, 150).removeClass('loading');
          $overall_rating.find('.trustometer * .numeric_rating').text(data.rating);
        }
      }
    });
/*
    $.post(OVERALL_RATING_URL, serialized_form, function(data) {
      $overall_trustometer_bar.animate({'width': data.percent + '%'}, 150).removeClass('loading');
      $overall_rating.find('.trustometer * .numeric_rating').text(data.rating);
    }, "json");
*/
  }
};

jQuery.fn.rating_input = function(options) {
  options = jQuery.extend({}, options);
  if (!options.disable_overall_rating) process_overall_rating();

  var $all_ratings = $(this);
  return $all_ratings.each(function() {

    var $stars = $(this).find('div.starselect a.star');
    var $rating_labels = $(this).find('div.rating_labels span');
    var $form_input = $(this).find('input.rating_value');
    var $metric = $(this).find('input.rating_criterion').attr('value');
    var $clear_link = $(this).find('a.clear_stars');

    var select_stars = function(select_index) {
      $stars.removeClass("sel").slice(0, select_index).addClass("sel");
      $rating_labels.hide();
      if (select_index > 0) $rating_labels.eq(select_index-1).show();  // In jquery 1.4.2 indexes wrap around!
    };
    var reset_stars = function() {
      var clear_index = ($form_input.attr('value') != "") ? $form_input.attr('value') : 0;
      select_stars(clear_index);
      return false;
    };

    reset_stars();

    // Dummy click handler to sync ratings & labels
    $(this).find('a.dummy').click(function() { reset_stars(); process_overall_rating(); });
    
    $clear_link.click(function() {
      $form_input.attr('value', "");
      if (options.sync_labels) update_review_label($metric, 0);   // clear
      reset_stars();
      process_overall_rating();
      if (options.submit_on_click) submit_with_onsubmit($(this).parents('form'));
      return false;
    });
    
    return $stars.mouseover(function() {
      select_stars($stars.index(this)+1);
    }).mouseout(function() {
      reset_stars();
    }).click(function() {
      var rating_val = $stars.index(this) + 1;
      $form_input.attr('value', rating_val);
      if (options.sync_labels) update_review_label($metric, rating_val);
      process_overall_rating();
      if (options.submit_on_click) submit_with_onsubmit($(this).parents('form'));
      return false;
    });
  });
};
