$('document').ready(function() {
  function toggle_ctxt_settings(button, ctxt) {
    var elt  = $('.' + ctxt + '_setting')
    if ($(button).length > 0) {
      $(button).is(':checked') ? elt.show() : elt.hide()
      $(button).parent().show()
    }
  }

  function toggle_specific_settings(button, ctxt, boxes) {
    var checked = $(button).is(':checked')
    for (var i = 0; i < boxes.length; i++) {
      var elt = $('#' + ctxt + '_setting_' + boxes[i])
      checked ? elt.show() : elt.hide()
    }
  }

  function toggle_row1(button) { toggle_specific_settings(button, 'grid', ["row1_label", "c1", "c2", "c3"]) }
  function toggle_row2(button) { toggle_specific_settings(button, 'grid', ["row2_label", "c4", "c5", "c6"]) }

  function toggle_grid_settings(grid_box, row1_box, row2_box) {
    toggle_ctxt_settings(grid_box, 'grid')
    if ($(grid_box).is(':checked')) {
      toggle_row1(row1_box)
      toggle_row2(row2_box)
    }
  }

  function toggle_slide(slide, checked) {
    var content = $(slide).find("div.slide_content");
    checked ? content.show() : content.hide()
  }

  function show_carousel_slide_object(slide) {
    var otype = $(slide).find("div.radio input:checked").val();
    $(slide).find("div.object").hide();
    $(slide).find("div.slide_" + otype).show();
  }

  function init_carousel_slides() {
    $("div.slide").each(function(i, slide) {
      var content = $(slide).find("div.slide_content");
      var cbox = $(slide).find("input.cbox")
      cbox.change(function() { toggle_slide(slide, $(this).is(':checked'))});
      content.find("div.radio input").change(function() { show_carousel_slide_object(slide); });

      toggle_slide(slide, cbox.is(':checked'));
      show_carousel_slide_object(slide);
    });
  }

  var staging_box = $('#staging_setting_show_box input')
  var row1_box    = $('#grid_setting_show_row1 input')
  var row2_box    = $('#grid_setting_show_row2 input')
  var grid_box    = $('#grid_setting_show_box input')
  var nc_box      = $('#news_comparison_setting_show_box input')

  // click handlers
  staging_box.change(function() { toggle_ctxt_settings(staging_box, 'staging') });
  row1_box.change(function() { toggle_row1(row1_box) });
  row2_box.change(function() { toggle_row2(row2_box) });
  grid_box.change(function() { toggle_grid_settings(grid_box, row1_box, row2_box) });
  nc_box.change(function() { toggle_ctxt_settings(nc_box, 'news_comparison') });

  // init state
  toggle_ctxt_settings(staging_box, 'staging')
  toggle_grid_settings(grid_box, row1_box, row2_box)
  toggle_ctxt_settings(nc_box, 'news_comparison')
  init_carousel_slides();
});
