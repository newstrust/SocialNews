function parse_results(response) {
  if (response[0]) {
      if(response[0].data[0] === '1') {
        $('#name_result').html('Name Already Taken');
        $("#name_result").addClass("name_unavailable");
        $("#name_result").removeClass("name_available");
      } else {
        $('#name_result').html('Name Available');
        $("#name_result").addClass("name_available");
        $("#name_result").removeClass("name_unavailable");
      }
  }
}

/*
 I extended the autocomplete class with an onData option, which will make a callback after the 
 autocomplete displays.
*/
$(document).ready(function() {
  // SSS: To ensure that this variable is always defined!
  if (typeof(formatted_login_available_members_path) == 'undefined') {
    var formatted_login_available_members_path = '/members/login_available.js';
  }
  // SSS: Do not add dataType: json declaration because it breaks parsing for the result that is returned by the ajax call
  var a = $("#member_name").autocomplete(formatted_login_available_members_path, {
    minChars: 3,
    cacheLength: 10,
    selectFirst:false,
    attachTo: 'hidden_autocomplete',
    extraParams:{ '_method' : 'get'},
    onData: function(data){parse_results(data);}
  });
});
