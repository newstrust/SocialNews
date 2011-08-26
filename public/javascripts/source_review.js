$(document).ready(function () { activate_review_form(); })

var init_selection = [];
function activate_review_form() {
  if (member_id == 0) {
    $('span.add_your_two_cents a').click(function() { show_login_dialog(); });
    $('span.review_link a').click(function() { show_login_dialog(); });
	  $('.source_review_input .rating_input').click(function() { 
      show_login_dialog();
      return false; 
    });
  }
  else {
    $('span.add_your_two_cents a').click(function() { $('#source_review_form').toggle(); $('#source_review_rating').show(); return true; });
    $('span.review_link a').click(function() { $('#source_review_form').toggle(); $('#source_review_rating').show(); return true; });
    $('#cancel_button').click(function() { $('#source_review_form').toggle(); $('#source_review_rating').show(); });
    $('div#expertise_topics').source_review_topic_autocomplete("source_review[expertise_attrs]", topic_taxonomy, init_selection);
	  $('.source_review_input .rating_input').rating_input({disable_overall_rating: true});
  }
}

function handle_save_response(resp, error) {
  var form = $("#source_review_form")
  reactivateSubmit(form);
  if (error || resp.error_message) {
    if (resp.error_message) {
      $("#source_review_form p.error").html(resp.error_message).show();
    }
    else {
      var err_msg = "Please reload this page and try again.  If the error persists, please email us at feedback@socialnews.com.";
      $("#source_review_form p.error").html(err_msg).show();
    }
  }
  else {
    form.hide();
    $("li.my_review").prepend('<div style="clear:both;color:#01a163;font-weight:bold;font-size:12px;margin-bottom:20px;">Your review has been saved.  Please reload page to see your updated review entry here.</div>');
/**
    var rating = resp.rating;
    $("li.my_review div.trustometer div.bar div").css("width", (rating * 20) + "%");
    $("li.my_review div.trustometer div.numeric_rating").html(rating + ".0");
**/
  }
}
