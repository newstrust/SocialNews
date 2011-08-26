/**
* Admin groups UI; used for group admin as well as topic/subject/source host admin
*
* The returned format from the autocomplete will be 
* name|email|id
*/

function formatItem(row) {
  return row[0] + "<br><i>" + row[1] + "</i>";
}

$(document).ready(function() {
  $("div.member_autocomplete").each(function() {
    var $div = $(this); 
    var ac_id = $div.attr("id");
    var SEARCH_PATH         = ac_id == '' ? FORMATTED_SEARCH_ADMIN_MEMBERS_PATH : eval(ac_id + "_member_search_path");
    var MEMBER_LISTING_PATH = ac_id == '' ? FORMATTED_ADMIN_GROUP_MEMBERS_PATH  : eval(ac_id + "_member_listing_path");

    $div.find("#autocomplete").autocomplete(SEARCH_PATH, {
      minChars: 3,
      matchSubset: 1,
      matchContains: 1,
      cacheLength: 10,
      dataType: 'json',
      formatItem: formatItem
    });

    $div.find('input#autocomplete').result(function(event, data, formatted) {
      if (data) {
        showMemberOptions(data);
      }
    });

    $div.find('#add_action').bind('click',
      function() {
        $.ajax({
          type: "POST",
          url: $div.find('#add_action').attr('href'),
          data: 'id=' + $div.find('#member_id').attr('title'),
          success: function(msg) {
            $div.find('#member_options').hide();
            memberlist();
          },
          error: function(msg) {
            switch (msg.status) {
            case 406:
              alert("Error adding member to group.");
              break;
            }
          }
        });
        return false;
      });

    $div.find('#cancel_action').bind('click',
      function() {
        $div.find('#member_options').hide();
      });

    function showMemberOptions(data) {
      if (typeof(data) == 'string') { return false; }
      
      $div.find('#member_options').show();
      $div.find('#member_name').text("Add " + data[0] + " to this group?");
      $div.find('#member_id').attr('title', data[2]);
      $div.find('#member_details').html("<ul><li>Name: " + data[0] + "</li><li>Email: " + data[1] + "</li></ul>");
    }

    function memberlist() {
      $.getJSON(MEMBER_LISTING_PATH+'?per_page=1000',
      function(data) {
        display_memberlist(data);
      });
    }

    function display_memberlist(data) {
      $div.find("#member_list").empty();
      $.each(data,
      function(i, item) {
        $div.find("#member_list").append('<tr><td><a href="/members/'+item.id+'">' + item.name + '</a></td><td><a id="remove_member_' + item.id + '"href="#"><img alt="Delete" src="/images/icons/delete.png" /></a></td></tr>');

        var delete_url = MEMBER_LISTING_PATH.split('.');
        delete_url = delete_url[0] + '/' + item.id + '/leave.' + delete_url[1];

        // bind the remove member action to this member
        $div.find('#remove_member_' + item.id).bind('click',
        function() {
          $.post(delete_url, '_method=delete',
          function(data) {
            display_memberlist(data);
          },
          "json");
          return false;
        });
      });
    }
  });

  // toggle display of listing tabs based on notabs checkbox
  $("#story_listings div#no_tabs input[type=checkbox]").change(function() { $("#story_listings div#tab_options").toggle(); });

  var sel_obj = $("#social_group_attributes_default_listing")
  $("#story_listings div#tab_options input[type=checkbox]").change(function() {
    // get current selection
    var curr_val = sel_obj.val();
    // remove everything
    sel_obj.find('option').remove();
    // add selections back
    var options = sel_obj.attr("options");
    var selected_listings = $("#story_listings div input:checked")
    var mynews_present = false
    for (var i = 0; i < selected_listings.length; i++) {
      var l = selected_listings[i];
      var l_val = $(l).attr("name").replace(/group\[listings\]\[(.*)\]/, "$1")
      var l_txt = $(l).siblings("label").text();
      options[i] = new Option(l_txt, l_val)
      if (l_val == "new_stories") mynews_present = true
    }

    // Show/hide mynews config link
    if (mynews_present) $("#mynews_config_link").show();
    else $("#mynews_config_link").hide();

    // reset selection
    sel_obj.val(curr_val);
  });
});
