/**
*
* Popup.js - NT popup window code, mostly legacy, some new stuff
*
*/


/**
* jQuery tie-ins; manipulate the DOM as necessary before opening widow
*/
function open_popup(url, link, dimensions) {
  if (link) $(link).pulse(true);
  /* SSS: Added this check Aug 22nd to not add popup=true url param to submits! */
  /* SSS: Added 2nd check Sep 23rd to not add duplicate popup=true url param to toolbar popus! */
  if (url.match(/\/submit\?/) || url.match(/popup=true/)) {
    Popup.open(url, false, dimensions);
  }
  else {
    Popup.open(add_popup_querystring(url), false, dimensions);
  }
  return true;
};
function add_popup_querystring(url) {
  var url_components = new RegExp(/([^#]+)(#.+)?/).exec(url);
  var has_query_params = url.match(/\?/);
  return url_components[1] + (has_query_params ? "&" : "?") + "popup=true" + ((url_components.length>2 && url_components[2]) ? url_components[2] : "");
};

function process_popup_links() {
  // insert popup query string into url for FAQs, etc.; submit can go this path, too
	$('a.popup_link').click(function() {
	  Popup.open(add_popup_querystring($(this).attr('href')), !$(this).hasClass('info_popup'));
		return false;
	});
	if (expand_window) Popup.expand();
}

$(document).ready(function() { process_popup_links(); });


/**
* Popup class does your window creating/resizing
*/
var Popup = {
  // constants
  popupWidth: 400, // can't go below 430 or FF Mac throws the scrollbar out
  popupHeight: 750,
  defaultFullWindowWidth: 990, // 950 + 40?
  defaultFullWindowHeight: 800,
  
  /**
  * Open a new popup window
  */
  open: function(url, saveScreenDimensions, dimensions) {
    if (saveScreenDimensions) this.saveScreenDimensions()

    var h, w;
    if (dimensions && dimensions.height) h = dimensions.height
    else h = this.popupHeight;
    if (dimensions && dimensions.width) w = dimensions.width
    else w = this.popupWidth;
    
  	// determine popup window location
  	var reviewPaneX = this.getWindowLeft() + this.getWindowWidth(); // have it sit alongside if possible
  	if (reviewPaneX + w > this.getScreenWidth()) { // otherwise, stick it where it will fit
  		reviewPaneX = this.getScreenWidth() - w
  	}
  	var reviewPaneY = this.getWindowTop()
    
    // open the popup
    // note that IE6 alone treats these dimensions as browser window w/ chrome... tough luck.
    w = window.open(url, "_blank",
      "width=" + w + "," +
      "height=" + h + "," +
      "left=" + reviewPaneX + "," +
      "top=" + reviewPaneY + "," +
      "scrollbars=yes,resizable=yes,status=yes,directories=yes,location=yes");
  },
  
  /**
  * Expand current ostensibly popup-sized window to full dimensions, from user's prefs if possible.
  */
  expand: function() {
    var fullWindowWidth = this.getIntCookie("SocialNewsWinW") || this.defaultFullWindowWidth
    var fullWindowHeight = this.getIntCookie("SocialNewsWinH") || this.defaultFullWindowHeight
    
    // resize window (& scootch left if falling off the screen)
    var windowXOverflow = (this.getWindowLeft() + fullWindowWidth) - this.getScreenWidth()
    if (windowXOverflow > 0) self.moveBy(-windowXOverflow, 0)
    self.resizeTo(fullWindowWidth, fullWindowHeight)
  },
  
  /**
  * Save user's current window size so we can try to expand back to that later
  */
  saveScreenDimensions: function() {
  	setCookie("SocialNewsWinW", this.getWindowWidth(), "", "/")
  	setCookie("SocialNewsWinH", this.getWindowHeight(), "", "/")
  },
  
  // cookie helper
  getIntCookie: function(name) {
    var val = getCookie(name)
    return val ? parseInt(val) : null
  },
  
  /**
  * Screen dimension helpers ("cross-platform")
  */
  // screenX/screenY (Saf/FF only) are preferred, as they give us the top of the _window_ (incl. browser chrome),
  // not just the render canvas, which is what screenLeft/screenTop (IE) give us
  getWindowLeft: function() {return parseInt(window.screenX || window.screenLeft)},
  getWindowTop: function() {return parseInt(window.screenY || window.screenTop)},
  
  // Likewise, outerWidth/outerHeight (Saf/FF only) give us the dimensions of the window w/ chrome,
  // while the document.documentElement values give us the render canvas dims again.
  // (The document.body values return what you'd expect in all browsers: not useful for windowing.)
  // To "be cool" to IE saps, add a fudge factor to these dims so it feels more sane.
  getWindowWidth: function() {return parseInt(window.outerWidth || (document.documentElement.clientWidth + 40))},
  getWindowHeight: function() {return parseInt(window.outerHeight || (document.documentElement.clientHeight + 140))},
  
  // For once, IE behaves like a normal browser.
  getScreenWidth: function() {return parseInt(self.screen.width)}
}


/**
* Cookie helpers
*/

/*
   name - name of the cookie
   value - value of the cookie
   [expires] - expiration date of the cookie
     (defaults to end of current session)
   [path] - path for which the cookie is valid
     (defaults to path of calling document)
   [domain] - domain for which the cookie is valid
     (defaults to domain of calling document)
   [secure] - Boolean value indicating if the cookie transmission requires
     a secure transmission
   * an argument defaults when it is assigned null as a placeholder
   * a null placeholder is not required for trailing omitted arguments
*/
function setCookie(name, value, expires, path, domain, secure) {
  var curCookie = name + "=" + escape(value) +
      ((expires) ? "; expires=" + expires.toGMTString() : "") +
      ((path) ? "; path=" + path : "") +
      ((domain) ? "; domain=" + domain : "") +
      ((secure) ? "; secure" : "");
  document.cookie = curCookie;
}

/*
  name - name of the desired cookie
  return string containing value of specified cookie or null
  if cookie does not exist
*/
function getCookie(name) {
  var dc = document.cookie;
  var prefix = name + "=";
  var begin = dc.indexOf("; " + prefix);
  if (begin == -1) {
    begin = dc.indexOf(prefix);
    if (begin != 0) return null;
  } else
    begin += 2;
  var end = document.cookie.indexOf(";", begin);
  if (end == -1)
    end = dc.length;
  return unescape(dc.substring(begin + prefix.length, end));
}

/*
   name - name of the cookie
   [path] - path of the cookie (must be same as path used to create cookie)
   [domain] - domain of the cookie (must be same as domain used to
     create cookie)
   path and domain default if assigned null or omitted if no explicit
     argument proceeds
*/
function deleteCookie(name, path, domain) {
  if (getCookie(name)) {
    document.cookie = name + "=" +
    ((path) ? "; path=" + path : "") +
    ((domain) ? "; domain=" + domain : "") +
    "; expires=Thu, 01-Jan-70 00:00:01 GMT";
  }
}
