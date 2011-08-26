var group_id = null, last_activity_entry_id = null;

$(document).ready(function() {
  init_activity_listing();
});

function init_activity_listing() {
  $('.more_activity').click(function() {
    var button = $(this)
    button.pulse(true, '', true)
    fetch_more_activity(button)
    return false;
  })
}

function fetch_more_activity(button) {
  $.ajax({
    url      : '/groups/' + group_id + '/ajax_stories',
    type     : 'get',
    dataType : 'html',
    data     : { listing_type: "activity", last_activity_entry_id: last_activity_entry_id },
    success  : function(entries) {
      button.pulse(false, '', true)
      if (last_activity_entry_id == -1) $(button).hide(); // No more activity entries for you!
      $('#paging_placeholder').before(entries)
    },
    error : function(obj, errStatus) {
      if (errStatus == 'timeout') alert('We are sorry! Looks like the server is busy. Please wait for about 30 seconds and try again.')
    }
  })
}
