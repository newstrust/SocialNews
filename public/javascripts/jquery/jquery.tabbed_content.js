/**
* tabbed_content plugin
*/

// global for pages to write to
var tab_to_select = null;

jQuery.fn.tabbed_content = function(callback, tabs_selector, tabbed_panes_selector, tab_classes) {
  var $tabs = $(this).find(tabs_selector);
  var $tabbed_panes = $(this).find(tabbed_panes_selector);
  
  var select_tab = function(select_index) {
    $tabs.removeClass("sel").eq(select_index).addClass("sel");
    $tabbed_panes.removeClass("sel").eq(select_index).addClass("sel");
    try{
      if (callback) {
        if (tab_classes) eval("(" + callback + ")('" + tab_classes[select_index] + "')");
        else eval(callback + "()");
      }
    }catch(e){}
  };
  
  $(document).ready(function() {
    var anchor = path_anchor() || tab_to_select; // if no anchor, use special default tab
    if (anchor) {
      $tab_to_select = $tabbed_panes.filter("."+anchor);
      if ($tab_to_select.length) select_tab($tabbed_panes.index($tab_to_select));
    }
  });
  
  return $tabs.click(function() {
    select_tab($tabs.index(this));
    $(this).blur();
    return false;
  });
};

/**
* Get the page anchor
*/
function path_anchor() {
  var anchor_matches = location.href.match(/#(.+)/);
  if (anchor_matches && anchor_matches.length) return anchor_matches[1];
};
