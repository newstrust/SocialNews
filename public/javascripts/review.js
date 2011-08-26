/**
* Review Form JS
*/

var review_form_expanded = false; // global variable that will be in initialized in a rails view.

$(document).ready(function () {
	var $rating_inputs     = $('div.rating_input');
  var $quality_labels    = $('div.row');
  var $popularity_labels = $('div.question');
  var $form_version_menu = $('select#review_form_version');
  var curr_form_type     = null; // 'rating' or 'label'
  var curr_form_level    = null; // 'mini', 'quick', 'full', 'advanced'

	/**
	 * Rating inputs have clickable help links, blue background, etc.
	 */
	var $current_rating_input = null;
	$rating_inputs.rating_input({sync_labels:true})
		.mouseover(function() {
			$(this).addClass("rating_input_sel").find('.subquestion span').show();
			$current_rating_input = $(this);
		}).mouseout(function() {
		  var $rating_input_div = $(this);
		  // do this the hard way w/ a timeout so that IE won't flicker on refresh when mousing over ratings boxes
			setTimeout(function() {
			  if (!$current_rating_input || $rating_input_div.not($current_rating_input).length) { // just testing (a != b) the hard way
			    $rating_input_div.removeClass("rating_input_sel");
          if (!$rating_input_div.find('a.toggle_rating_description img').hasClass('sel')) {
            $rating_input_div.find('.subquestion span').hide();
          }
			  }
			}, 1);
			$current_rating_input = null;
		}).find('a.toggle_rating_description').click(function() {
		  return toggle_rating_description($(this).parents('.rating_input').find('.description'));
		});

	/**
	 * Form Version (= rating:mini, rating:quick, rating:full, rating:advanced, label:mini, label:quick, label:full, label:advanced)
	 */

  function display_form_level_inputs(form_version_options, form_version_index, metrics) {
    var i = 0;
    form_version_options.each(function(index) {
      var parts = this.split(":")
      if (parts[0] == curr_form_type) {
        var version_metric = metrics.filter("." + parts[1]);
        if (form_version_index >= i) version_metric.show();
        else version_metric.hide();
        i++;
      }
    });
  }

	function set_form_version(speed) {
    var form_version = $form_version_menu.val()
    var parts = form_version.split(":")
    curr_form_type = parts[0]
    curr_form_level = parts[1]

    var metrics = null;
    var form_version_options = get_form_versions();
    var form_version_index = -1;
    var i = 0;
	  form_version_options.each(function(index) { 
      var parts = form_version_options[index].split(":");
      if (parts[0] == curr_form_type) {
        if (parts[1] == curr_form_level) form_version_index = i;
        i++;
      }
    });

    if (curr_form_type == 'rating') {
      $('#review_labels').hide();
      $('#rating_inputs').show();
      $('.form_header #ratings_header').show();
      $('.form_header #labels_header').hide();
      display_form_level_inputs(form_version_options, form_version_index, $rating_inputs);
    }
    else {
      $('#rating_inputs').hide();
      $('#review_labels').show();
      $('.form_header #ratings_header').hide();
      $('.form_header #labels_header').show();
      display_form_level_inputs(form_version_options, form_version_index, $quality_labels);
      display_form_level_inputs(form_version_options, form_version_index, $popularity_labels);
    }

    limit_form_height();
  }

	function get_form_versions() {
	  var form_versions = new Array();
	  $form_version_menu.find('option').each(function(index) {
	    form_versions.push($(this).val());
	  });
	  return $(form_versions);
	}

	$form_version_menu.change(function() {
	  set_form_version(180);
    process_overall_rating();
	});

  $('#review_form div.share a#facebook_button').click(function() {
    $('#review_form #post_on_facebook').attr('checked', $(this).hasClass("selected") ? '' : 'checked');
    $(this).toggleClass('selected');
    return false;
  })

  $('#review_form div.share a#twitter_button').click(function() {
    var cv = $(this).hasClass("selected") ? 1 : 0;
    $('#review_form #post_on_twitter').attr('checked', cv == 1 ? '' : 'checked');
    $(this).toggleClass('selected');
    toggle_tweet_box(cv, $('#tweet_box'), true);
    return false;
  })

  // resize form whenever the review form is expanded, the about you section is expanded, 
  // or any of the expanded review form tabs are clicked
  $('#review_form a.expand').click(function() { 
    $(this).toggleClass('selected'); 
    $('.expanded').toggle();
    limit_form_height(true);
    review_form_expanded = !review_form_expanded;
    $('#review_form input[name=review_form_expanded]').attr('value', review_form_expanded ? "1" : "");
  });
  $('#review_form .about_you').click(function() { limit_form_height(); });
  $("#review_form .expanded li").click(function() { limit_form_height(); });

  // initialize review form expansion status
  if (review_form_expanded) {
    review_form_expanded=false; // reset it
    $('#review_form a.expand').click();
  }

	set_form_version(1);
});

// more rating inputs: full description
function toggle_rating_description($rating_description) {
  // update rollover text for question mark icon - also update it in /views/reviews/_rating_input.html.erb
  if ($rating_description.parent('.rating_input').find('img').hasClass('sel')) help_title = "Click for more info";
  else help_title = "Click for less info";

  $rating_description.parent('.rating_input').find('a.toggle_rating_description').blur().find('img').toggleClass('sel').attr("title",help_title);
  $rating_description.slideToggle(50);
  return false;
}

/**
* Story relations (= 'links')
* ajax call to backend to create story & update our view here.
*/
function init_story_relations() {
  // set up story_lookup with custom handler
  $('.story_relation .story_lookup').story_lookup({related_story:1}, function(data, div) {
    if (!data.error) {
      var $story_relation = $(div).parents('.story_relation');
      $story_relation.find(story_relation_input_selector('related_story_id')).val(data.id);
      $story_relation.find(story_relation_input_selector('title')).val(data.title);
    }
	});
};
function remove_story_relation(story_relation) {
  if (confirm('Remove link?')) {
    $(story_relation).parents('.story_relation').hide().find(story_relation_input_selector('should_destroy')).val(true);
    if (in_toolbar) limit_form_height();
  }
}
function story_relation_input_selector(key) {
  var input_name = "story[story_relations_attributes][]["+key+"]";
  return "input[name='"+input_name+"']";
}

/**
* Excerpts (= 'quotes')
* this looks a lot like story relations above... should factor out batch_association commonalities.
*/
function remove_excerpt(excerpt) {
  if (confirm('Remove quote?')) {
    $(excerpt).parents('.excerpt').hide().find("input[name='review[excerpts_attributes][][should_destroy]']").val(true);
    if (in_toolbar) limit_form_height();
  }
}

/**
 * Generic Railsy helpers using jQuery.domec
 */
function link_to(text, url) {
  return jQuery.create('a', {href: url}, text);
};

function update_review_label(metric, rating_value) {
  var review_label_div = $("#review_label_" + metric);
  review_label_div.find("a.positive").removeClass("selected");
  review_label_div.find("a.negative").removeClass("selected");
  if (rating_value != 0) {
    if (rating_value < 3)
      review_label_div.find("a.negative").addClass("selected");
    else
      review_label_div.find("a.positive").addClass("selected");
  }
}

function select_label(label_button, metric, label, rating_value) {
  var button = $(label_button);

  // Update corresponding rating input value with the rating value
  var prefix   = (metric == "trust") ? "source_ratings" : "review\\[rating_attributes\\]";
  var selector = "input[name=" + prefix + "\\[" + metric + "\\]\\[value\\]]";
  if (button.hasClass("selected")) {
    $(selector).attr("value", "");
    $(selector).parents('div.rating_input').find('a.dummy').click();
  }
  else {
    $(selector).attr("value", rating_value);
    $(selector).parents('div.rating_input').find('a.dummy').click();
  }

/**
// SSS: NOTE
// Right now, the label input values aren't required -- the labels can just be a front-end
// UI thing, and all labels can be converted to rating inputs as before.  But, if in the future, 
// we want to diverge the rating & labelling forms, at that time, we will need these labels stored
// in the db in some form.  In anticipation, I am retaining that code, but commenting it out

  if (button.hasClass("selected"))
    button.parent('div').find("input").attr("value", "");
  else
    button.parent('div').find("input").attr("value", label);
 **/

  // Update 'selected' class
  button.toggleClass("selected");

  // Remove 'selected' class from the other button
  button.siblings("a").removeClass("selected");
}

function switch_to_label_form(member) {
  var form_version_menu = $('select#review_form_version');
	form_version_menu.val(form_version_menu.val().replace(/rating/, "review"));
  form_version_menu.change();
}
