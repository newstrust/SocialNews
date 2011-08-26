/**
* Story listing JS
*/

/**
* Menus should trigger refresh immediately
*/
$(document).ready(function() {
  //$("select, input[type='radio']").change(refresh_listing);
  $('form#story_filters_form').submit(refresh_listing);
  $('span.timespan').click(function(ev)   { refresh_listing_dates(ev) });
  $('div.filter_header').click(function() { $('div.filter_form_div').toggleClass("filters_hidden").toggleClass("filters_shown"); });
});

function refresh_listing_dates(ev) {
  $('span.selected').removeClass("selected").addClass("timespan");
	$(ev.target).removeClass("timespan").addClass("selected");
  refresh_listing();
}

/**
* Format pretty story listings url; sort of reverse-engineering our own routing logic here
*/
function refresh_listing() {
  var current_url  = document.location.href;
  var listing_type = $("#listing_type").val();
  var base_url = current_url.replace(/(http:\/\/.*\/((groups\/\d+)|stories|(subjects|topics|sources)\/\w*)).*/, function(m, base_path) { return base_path; }) + "/" + listing_type;

  $(["story_type"]).each(function() {
    var val = $("#"+this).val();
    if (val != "") base_url += "/" + val
  });

  $(["source_ownership"]).each(function() {
    var val = $("#"+this).val();
    if ((val == "independent") || (val == "mainstream")) {
      base_url += "/" + val
    }
    else if (val != "") {
      $.query.SET(this, val);
    }
    else {
      $.query.REMOVE(this);
    }
  });

  // then the query string
  $(["media_type", "story_ratings", "story_status"]).each(function() {
    var val = $("#"+this).val();
    if (val != "") $.query.SET(this, val);
    else $.query.REMOVE(this);
  });

    // add the timespan value
  var timespan_elt = $('span.selected')[0];
  if (timespan_elt) {
    if (timespan_elt.id) {
      var timespan = timespan_elt.id.replace(/timespan_/, '');
      $.query.SET("timespan", timespan);

        // Remove all date params
      $.query.REMOVE("start_date");
      $.query.REMOVE("end_date");
      $.query.REMOVE("review_start_date");
      $.query.REMOVE("review_end_date");
    }
    else {
      if (listing_type == "recent_reviews") {
        var r_start = current_url.replace(/.*review_start_date=(\d*\.\d*\.\d*).*/, function(m, d) { return d; });
        var r_end   = current_url.replace(/.*review_end_date=(\d*\.\d*\.\d*).*/, function(m, d) { return d; });
        if (r_start != current_url) $.query.SET("review_start_date", r_start);
        if (r_end != current_url) $.query.SET("review_end_date", r_end);
        $.query.REMOVE("start_date");
        $.query.REMOVE("end_date");
      }
      else {
        var start = current_url.replace(/.*[^_]start_date=(\d*\.\d*\.\d*).*/, function(m, d) { return d; });
        var end   = current_url.replace(/.*[^_]end_date=(\d*\.\d*\.\d*).*/, function(m, d) { return d; });
        if (start != current_url) $.query.SET("start_date", start);
        if (end != current_url) $.query.SET("end_date", end);
        $.query.REMOVE("review_start_date");
        $.query.REMOVE("review_end_date");
      }
    }
  }
  else {
    $.query.REMOVE("timespan");
  }

  // Remove paging params!
  $.query.REMOVE("page");

  // show a clean url in the location bar, and fetch the new listing
  document.location = base_url + $.query;

  // do not submit the form!
  return false;
};
