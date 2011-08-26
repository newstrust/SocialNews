var init_selection = '';

$(document).ready(function () {
  if (member_id == 0) {
    $(".source_entry a.full_review, .quick_source_review_input .rating_input").click(function() { 
      show_login_dialog();
      return false; 
    });
  }
  else {
    $(".source_entry a.full_review").click(function() { 
      fetch_review_form(this);
      return false; 
    });
	  $('.quick_source_review_input .rating_input').rating_input({submit_on_click: true, disable_overall_rating: true});
  }
});

var infoDialog = null;
function show_info_dialog() {
  if (infoDialog == null)
    infoDialog = $('#info_dialog_container').dialog({autoOpen:false, modal:false, title:"", height: 50, width:'auto', resizable: false})

  $("#info_dialog_container .info").html("Fetching your source review form.  Please wait ...")
  infoDialog.dialog("open");
  infoDialog.find(".info").pulse(true);
}

function close_info_dialog() {
  infoDialog.find(".info").pulse(false);
  infoDialog.dialog("close");
}

var sourceReviewFormDialog = null;
function show_source_review_form_dialog() {
  if (sourceReviewFormDialog == null)
    sourceReviewFormDialog = $('#source_review_form_dialog_container').dialog({autoOpen:false, modal:false, title:"", height: 'auto', width:'auto', resizable: false, closeOnEscape: false, dialogClass: 'source_review_dialog'})

  sourceReviewFormDialog.dialog("open");
}

function close_source_review_form_dialog() {
  sourceReviewFormDialog.dialog("close");
}

function prepare_form(form) {
  $("div#expertise_topics").source_review_topic_autocomplete("source_review[expertise_attrs]", topic_taxonomy, init_selection);
  form.find(".rating_input").rating_input({disable_overall_rating: true});
  form.find("#cancel_button").click(close_source_review_form_dialog);
  process_popup_links();
}

function fetch_review_form(button) {
  show_info_dialog();

  var src_id = $(button).attr("id").replace(/source_review_source_/, '');
  $.ajax({
    url      : '/sources/' + src_id + '/edit_source_review.js',
    type     : 'get',
    dataType : 'html',
    success  : function(form) {
      var form = $("#source_review_form_dialog_container #form_placeholder").html(form);
      close_info_dialog();
      prepare_form(form);
      show_source_review_form_dialog();
    }
  });
}

function handle_save_response(resp, error) {
  if (error || resp.error_message) {
    reactivateSubmit($("#source_review_form_dialog_container #form_placeholder"));
    if (resp.error_message) {
      $(".source_review_form p.error").html(resp.error_message).show();
    }
    else {
      var err_msg = "Please reload this page and try again.  If the error persists, please email us at feedback@socialnews.com.";
      $(".source_review_form p.error").html(err_msg).show();
    }
  }
  else {
    // sync rating!
    var src_id = resp.source_id;
    var rating = resp.rating;
    var rating_val_input = $('#source_review_'+src_id + ' #source_review_rating_attributes_trust_value');
    rating_val_input.attr("value", rating);
    rating_val_input.parents('div.rating_input').find('a.dummy').click();

    close_source_review_form_dialog();
    $("#info_dialog_container .info").html("Your review has been saved.");
    infoDialog.dialog("open");
    setTimeout(close_info_dialog, 1500);
  }
}
