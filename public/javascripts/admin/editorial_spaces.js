$(document).ready(function() {
  $('div#eb_slugs a').click(function() {
    var curr_slugs = $('#editorial_space_editorial_block_slugs').attr("value");
    $('#editorial_space_editorial_block_slugs').attr("value", curr_slugs + ((curr_slugs == "") ? "" : ", ") + $(this).html());
    return false;
  });
});
