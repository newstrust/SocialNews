var _tabs_empty={};

function switch_tab(api, e, index) {
  var t  = api.getTabs().eq(index)
  var tab = t.attr('href').replace(/#/, "")
  if (_tabs_empty[tab]) {
    var url = window.location.href.replace(/(\/show)?(#.*)?(\?.*)?$/, '/ajax_stories')
    var content_div = $('div.panes #listing_' + tab)
    content_div.html("<p style='margin:10px 20px 30px 20px;font-size:20px;font-weight:bold;' id='loading_msg'> Fetching ... </p>")
    $('#loading_msg').pulse(true, '', true)
    $.ajax({
      url      : url,
      type     : 'get',
      dataType : 'html',
      data     : { listing_type : tab },
      success  : function(listing) {
        _tabs_empty[tab] = false
        content_div.html(listing)
        if (tab_switch_callbacks[tab]) {
          setTimeout(tab_switch_callbacks[tab], 100) // FIXME: Arbitrary! Use a 100 ms timeout to give the js interpreter a chance to parse everything
        }
        // For facebook, of course!
        try { FB.XFBML.Host.parseDomTree() } catch(err) {}
      },
      error : function(obj, errStatus) {
        if (errStatus == 'timeout') alert('We are sorry! Looks like the server is busy. Please wait for about 30 seconds and reload this page.')
      }
    })
  }
}
