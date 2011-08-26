/* ******************************************************************************
 * 1. All globally visible functions / objects have been prefixed with _GLOB_.
 *    All these names will be renamed to a form _NTW_4 by a js code compression
 *    script to minimize chances of code/variable conflicts with other js code
 *    on the site where this widget will be embedded into!
 * 2. All local method names & variables starting with _PRIV_ will be renamed
 *    to a name of the form _v3 by a js code compression script!
 * 3. This rendering engine is expected to conform to the JS widget spec. which
 *    is part of the NT documentation.  So, if there is a mismatch, either the
 *    code has to change to conform to the spec. OR the spec. has to be updated
 *    to reflect the latest code changes.
 * 4. The functions _GLOB_setCookie, _GLOB_saveScreenDimensions, _GLOB_getCookie,
 *    and object _GLOB_Popup have been copied from popup.js 
 *    to keep this js file self-contained, and also to keep to a minimum the
 *    total js code that is pulled from NT servers.
 * ****************************************************************************** */

function _GLOB_defined(v)  { return (typeof v != 'undefined'); }

var _GLOB_isIE6 = false;

function _GLOB_detectBrowser()
{
  // from http://parentnode.org/javascript/javascript-browser-detection-revisited/
  var flag = false /*@cc_on || true @*/;
  _GLOB_isIE6 = flag && (document.implementation != null) && (document.implementation.hasFeature != null) && (window.XMLHttpRequest == null);
}

/**
* Popup class does your window creating/resizing
*/
var _GLOB_Popup = {
  // constants
  _PRIV_popupWidth: 430, // can't go below 430 or FF Mac throws the scrollbar out
  _PRIV_popupHeight: 750,
  _PRIV_defaultFullWindowWidth: 840,
  _PRIV_defaultFullWindowHeight: 800,
  
  /**
  * Open a new popup window
  */
  open: function(url, saveScreenDimensions) {
    if (saveScreenDimensions) this._PRIV_saveScreenDimensions()
    
  	// determine popup window location
  	var reviewPaneX = this._PRIV_getWindowLeft() + this._PRIV_getWindowWidth(); // have it sit alongside if possible
  	if (reviewPaneX + this._PRIV_popupWidth > this._PRIV_getScreenWidth()) { // otherwise, stick it where it will fit
  		reviewPaneX = this._PRIV_getScreenWidth() - this._PRIV_popupWidth
  	}
  	var reviewPaneY = this._PRIV_getWindowTop()
    
    // cook up a unique-ish window ID using the story ID. do we want this to ALWAYS be unique?
    // this code is a bit fragile as it depends on the URL structure...
    var storyIdMatches = new RegExp(/stories\/(\d+)/).exec(url)
    var storyId = (((storyIdMatches) && (storyIdMatches.length>1))?(storyIdMatches[1]):"")
    var reviewPaneName = "nt_review_" + storyId
    if (reviewPaneName==window.name) reviewPaneName += "_" // cheapo deduping.
    
    // open the popup
    // note that IE6 alone treats these dimensions as browser window w/ chrome... tough luck.
    window.open(url, reviewPaneName,
      "width=" + this._PRIV_popupWidth + "," +
      "height=" + this._PRIV_popupHeight + "," +
      "left=" + reviewPaneX + "," +
      "top=" + reviewPaneY + "," +
      "scrollbars=yes,resizable=yes,status=yes,directories=yes,location=yes,menubar=yes,toolbar=yes");
  },
  
  /**
  * Expand current ostensibly popup-sized window to full dimensions, from user's prefs if possible.
  */
  expand: function() {
    var fullWindowWidth = this._PRIV_getIntCookie("SocialNewsWinW") || this._PRIV_defaultFullWindowWidth
    var fullWindowHeight = this._PRIV_getIntCookie("SocialNewsWinH") || this._PRIV_defaultFullWindowHeight
    
    // resize window (& scootch left if falling off the screen)
    var windowXOverflow = (this._PRIV_getWindowLeft() + fullWindowWidth) - this._PRIV_getScreenWidth()
    if (windowXOverflow > 0) self.moveBy(-windowXOverflow, 0)
    self.resizeTo(fullWindowWidth, fullWindowHeight)
  },
  
  /**
  * Save user's current window size so we can try to expand back to that later
  */
  _PRIV_saveScreenDimensions: function() {
  	_GLOB_setCookie("SocialNewsWinW", this._PRIV_getWindowWidth(), "", "/")
  	_GLOB_setCookie("SocialNewsWinH", this._PRIV_getWindowHeight(), "", "/")
  },
  
  // cookie helper
  _PRIV_getIntCookie: function(name) {
    var val = _GLOB_getCookie(name)
    return val ? parseInt(val) : null
  },
  
  /**
  * Screen dimension helpers ("cross-platform")
  */
  // screenX/screenY (Saf/FF only) are preferred, as they give us the top of the _window_ (incl. browser chrome),
  // not just the render canvas, which is what screenLeft/screenTop (IE) give us
  _PRIV_getWindowLeft: function() {return parseInt(window.screenX || window.screenLeft)},
  _PRIV_getWindowTop: function() {return parseInt(window.screenY || window.screenTop)},
  
  // Likewise, outerWidth/outerHeight (Saf/FF only) give us the dimensions of the window w/ chrome,
  // while the document.documentElement values give us the render canvas dims again.
  // (The document.body values return what you'd expect in all browsers: not useful for windowing.)
  // To "be cool" to IE saps, add a fudge factor to these dims so it feels more sane.
  _PRIV_getWindowWidth: function() {return parseInt(window.outerWidth || (document.documentElement.clientWidth + 40))},
  _PRIV_getWindowHeight: function() {return parseInt(window.outerHeight || (document.documentElement.clientHeight + 140))},
  
  // For once, IE behaves like a normal browser.
  _PRIV_getScreenWidth: function() {return parseInt(self.screen.width)}
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
function _GLOB_setCookie(name, value, expires, path, domain, secure) {
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
function _GLOB_getCookie(name) {
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
function _GLOB_deleteCookie(name, path, domain) {
  if (_GLOB_getCookie(name)) {
    document.cookie = name + "=" +
    ((path) ? "; path=" + path : "") +
    ((domain) ? "; domain=" + domain : "") +
    "; expires=Thu, 01-Jan-70 00:00:01 GMT";
  }
}

// **** Code from here onwards is new to the javascript widget rendering engine ****

var _GLOB_relativeStarsDir = 'images/trustometer/';
var _GLOB_monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

// check for membership in an array
function _GLOB_arrayContains(arr, elt)
{
  for (var i = 0; i < arr.length; i++) {
    if (arr[i] == elt)
      return true;
  }
  return false;
}

function _GLOB_getRatingImageFile(rating, pngs)
{
  pngs = false; // no longer supported
    // |(rating * 2)| / 2 ==> rounding to nearest 0.5
    // Ex: 3.49 => |(3.49*2)|/2 = 3.0 => 3-0.gif
    //     3.51 => |(3.51*2)|/2 = 3.5 => 3-5.gif
    //     0.99 => |(0.99*2)|/2 = 1.0 => 1-0.gif
    //     1.49 => |(1.49*2)|/2 = 1.0 => 1-0.gif
  return ((Math.round(rating * 2) / 2).toPrecision(2)).replace(/\./, '-') + (pngs ? '.png' : '.gif');
}

// Copied from reviews.tpl and edited for use here.
function _GLOB_truncateTextChars(s, numChars, minChars, separator)
{
// truncate string s to numChars. Add ... to the end if it's > numChars. Try to truncate on a word boundary
// if separator is passed (e.g., a ',') then use that to split the words/phrases

  if (!s || (s.length <= numChars)) {
    return s;
  }
  else {
    s = s.substring(0,numChars);

    var pos = s.lastIndexOf(separator);
    if (pos > minChars) {
      s = s.substring(0,pos);
    }
    else if (separator != ' ') {
      pos = s.lastIndexOf(' ');
      if (pos > minChars)
        s = s.substring(0,pos);
    }
        
    return s + ' ...';
  } 
}

// copied from widgets.auto
function _GLOB_countWords(s) { return s.split(/\s+/).length; }

// copied from widgets.auto
function _GLOB_countWordsOfMinLength(s, minLen)
{
  var n = 0;
  var words = s.split(/\s+/);
  for (i = 0; i < words.length; i++) {
    if (words[i].length >= minLen)
        n++;
  }
  return n;
}

// copied from widgets.auto
function _GLOB_smartTruncate(s, maxLen)
{
  var s2 = _GLOB_truncateTextChars(s, maxLen, maxLen-15, ' '); 
  if (!s2) return s2;
  var numLongWords = _GLOB_countWordsOfMinLength(s2, 10);
  if (numLongWords > (maxLen-1)/50) {
    s2 = _GLOB_truncateTextChars(s, maxLen-10, maxLen-25, ' ');
  }
  else {
    var nw = _GLOB_countWords(s2);
    var avgWordLen = s2.length / nw;
    if (avgWordLen >= 7.5) {
        s2 = _GLOB_truncateTextChars(s, maxLen-10, maxLen-25, ' ');
    }
  }
  return s2;
}

function _GLOB_trim(str, max_length) { return (!max_length) ? str : _GLOB_smartTruncate(str, max_length); }

function _GLOB_formatDate(dateString, dateFormat)
{
/* 
 * This function formats dateString using the formatting string dateFormat 
 *
 * dateFormat replacement semantics are:
 * m  --> 2 digit month without leading 0's (1, 2, ..., 9, 10, 11, 12)
 * mm --> 2 digit month with leading 0's    (01, 02 ..., 09, 10, 11, 12)
 * M  --> 3-letter month abbreviation with first letter capitalized (Jan, .. Dec)
 * MM --> Full month name with the first letter capitalized (January, .. December)
 * d  --> 2 digit day without leading 0's   (1, 2, ..., 9, 10, ... 31)
 * dd --> 2 digit day with leading 0's      (01, 02, ..., 09, 10, ... 31)
 * y  --> 4 digit year
 *
 * Every other character in dateFormat is copied over verbatim
 */

  if (!dateFormat)
    return dateString;

  var vals = dateString.split('/');
  var y   = vals[0];
  var mm  = vals[1];
  var dd  = vals[2];
  var m   = mm.replace(/^0/, '');
  var d   = dd.replace(/^0/, '');
  var MM  = _GLOB_monthNames[m-1];
  var M   = MM.substr(0, 3);

    // ORDER of these expressions is important!
  return dateFormat.replace(/y/, y)
                   .replace(/dd/, dd)
                   .replace(/d/, d)
                   .replace(/mm/, mm)
                   .replace(/m/, m)
                   .replace(/MM/, MM)
                   .replace(/M/, M);

}

// Widget constructor!
function _NTW_Widget(stories, listingMetadata, widgetFormat)
{
  _GLOB_detectBrowser();

	var widget = this;	// COMPRESSION: copy a reference to the widget to enable better code compression

	widget._PRIV_stories = stories;					  // Story array
	widget._PRIV_metaData = listingMetadata;	// Metadata for the story listing
	widget._PRIV_widgetFormat = widgetFormat;	// Widget format
	widget._PRIV_rootDIV  = '';								// Main div of this widget
	widget._PRIV_init();
}

/***
 * Only publicly exported methods of the _NTW_widget are:
 *   setWidth      - sets the desired width of the generated width
 *   setNumStories - sets the # of stories to be rendered by the widget 
 *   setTrackingCode - sets the url tracking code
 *   setHideElts   - sets what story elements should be displayed / hidden
 *   install       - installs the widget by replacing the script element for *this* .js script file
 *   installOver   - replaces the DOM object passed in as argument with the widget
 *   refresh       - regenerates the widget and replaces it in-place
 ***/

_NTW_Widget.prototype = {
    // methods to let external js scripts modify these params
    // IMPORTANT: do not prefix these next 3 methods with _PRIV_
  setWidth: function(w) { if (w) this._PRIV_widgetFormat.base_css.base_style += ';width:' + w; },
  setNumStories: function(n) { if (n) this._PRIV_widgetFormat.content.num_stories = n; },
  setTrackingCode: function(c) { if (c) this._PRIV_widgetFormat.content.tracking_code = c; },
  setHideElts: function(hides) { 
				// if the user wants certain elements hidden, fix it up to make sure they are 
        // consistent with NT widget policies!
      hides['title'] = false;  // Title cannot be hidden!
      var showStars = !hides['stars'];
      if (showStars)
        hides['rating'] = false;  // Ratings cannot be hidden if user has asked for stars
      this._PRIV_widgetFormat.content.show_stars = showStars;
      this._PRIV_hideElts = hides;
    },

  setNewsHuntElts: function(nhElts) { 
      this._PRIV_newsHuntElts = nhElts;
    },

	_PRIV_init: function() {
			var widget  = this;					// COMPRESSION: copy a reference to the widget to enable better code compression
			var cssPrefs = widget._PRIV_widgetFormat.base_css;	// COMPRESSION: local variable to ensure better code compression!

			  // other global variables
			widget._PRIV_notEnoughReviewsForStory = 0;
      if (typeof(widget._PRIV_widgetFormat.content.tracking_code) == "undefined") widget.setTrackingCode("wid");

        // canonicalize base url
      var baseUrl = widget._PRIV_metaData.site_base_url;
      if (baseUrl.charAt(baseUrl.length-1) != '/') {
        baseUrl += '/';
      }

				// some shortcuts -- since preview, beta, www, all point to the main domain, canonicalize the base url!  
			widget._PRIV_baseUrl = baseUrl.replace(/www./, "").replace(/beta./, "").replace(/preview./, "");
			//widget._PRIV_amSignedIn = ntUserSignedInFlag;
			widget._PRIV_hoverStyle = (cssPrefs.link_class || !_GLOB_defined(cssPrefs.link_hover_style)) ? '' : cssPrefs.link_hover_style;
		},

		// Set a style on a DOM element
	_PRIV_setStyle: function(elt, clazz, styleText) {
			var widget = this;					// COMPRESSION: copy a reference to the widget to enable better code compression
			var cssPrefs = widget._PRIV_widgetFormat.base_css;	// COMPRESSION: local variable to ensure better code compression!

			if (clazz) {
				elt.setAttribute((document.all ? 'className' : 'class'), clazz);  // IE7 behavior is different from the rest of the pack!
			}
			else if (styleText) {
          // Convert relative urls to absolute ones!
        if (styleText.indexOf('url(') != -1 && styleText.indexOf('url(http://' == -1))
          styleText = styleText.replace('url(', 'url(' + widget._PRIV_baseUrl);

					 // this is for IE7 and not sure which other browsers
				if (elt.style.setAttribute) {
					elt.style.setAttribute('cssText', styleText);

						 // If a hover style is present, mimic it with onmouseover & onmouseout js handlers
					if ((elt.tagName == 'A') && widget._PRIV_hoverStyle) {
						elt.onmouseover = function() { this.style.setAttribute('cssText', styleText + ';' + widget._PRIV_hoverStyle); }
						elt.onmouseout  = function() { this.style.setAttribute('cssText', styleText); }
					}
				}
					 // this is for FF, Safari, and not sure which other browsers
				else {
					elt.setAttribute('style', styleText); 

						 // If a hover style is present, mimic it with onmouseover & onmouseout js handlers
					if ((elt.tagName == 'A') && widget._PRIV_hoverStyle) {
						elt.onmouseover = function() { this.setAttribute('style', styleText + ';' + widget._PRIV_hoverStyle); }
						elt.onmouseout  = function() { this.setAttribute('style', styleText); }
					}
				}
			}
				// if the element is an anchor element, retry with the generic style!
			else if ((elt.tagName == 'A') && (cssPrefs.link_style || cssPrefs.link_class)) {
				widget._PRIV_setStyle(elt, cssPrefs.link_class, cssPrefs.link_style);
			}
		},

  _PRIV_createElement: function(type, clazz, style) {
			var elt = document.createElement(type);
			this._PRIV_setStyle(elt, clazz, style);
			return elt;
		},

	_PRIV_createImage: function(src, altAttr, clazz, style) {
			var img = this._PRIV_createElement('img', clazz, style);
          // Handling PNGs in IE6: from http://24ways.org/2007/supersleight-transparent-png-in-ie6
      if (_GLOB_isIE6 && src.match(/\.png$/)) {
        img.style.width  = img.width + "px";
        img.style.height = img.height + "px";
        img.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + src + "', sizingMethod='scale')";
        img.src = "x.gif";
      }
      else {
			  img.src = src;
      }
			img.setAttribute('alt', altAttr);
			return img;
		},

  _PRIV_buildElementContainer: function(eltData, eltDOMArray, lastDOMElementProcessor) {
			var rootElt = '';
			var leafElt = '';
			var depth = eltDOMArray.length;

			/* 
			 * This code goes through the array of HTML element specs,
			 * constructs one elements at a time, and nests each new element
			 * within the previous element.
			 *
			 * The last element of the array is handled specially -- it is
			 * processed by the function 'lastDOMElementProcessor' that has been
			 * passed in.
			 */
			for (var i = 0; i < depth; i++) {
				var params = eltDOMArray[i];

					// Create element and set its style before 'lastDOMElementProcessor'
					// because it might create a new element altogether in some rare cases
					// (where the widget format is not compliant), and in those cases,
					// we don't want to overwrite the stye setting!
				var newElt = this._PRIV_createElement(params.elt, params.clazz, params.style);

					// Handle the last element specially!
				if (i == (depth-1))
					newElt = lastDOMElementProcessor(eltData, newElt, params);

				if (!rootElt)
					rootElt = newElt;
				else
					leafElt.appendChild(newElt);

				leafElt = newElt;
			}

				/* No DOM specs provided -- so, run the last element processor to generate a default element */
			if (depth == 0) {
				rootElt = lastDOMElementProcessor(eltData, '', params);
			}

			return rootElt;
		},

			/* This is a default element builder, where the element text is appended
			 * at the left of the DOM as plain text.  If the element's DOM array is
			 * empty (no formatting specs), it creates a text dom element */
	_PRIV_defaultTextElementBuilder: function(eltDOM, eltText) {
			return this._PRIV_buildElementContainer(
								eltText,
								eltDOM,
								function(eltData, newElt) {
									if (!newElt)
										newElt = document.createTextNode(eltData);
									else
										newElt.innerHTML = eltData;

									return newElt;
								}
						);
		},

		/* This is an anchor element builder, where the data element will be rendered as an anchor tag and linked to the supplied url.  
     * 1. If the data element's DOM array is empty (no formatting specs), it creates an <a> element.
     * 2. If 'alwaysA' is true, the method assumes (and DOES NOT check) that the data element's DOM array's last element is an <a> element.
     * 3. If 'alwaysA' is false, and newElt is not an 'A', 'linkText' is used as innerHTML of newElt
     * 4. If 'suppressUserDefinedLinkData' is true, any link text & url info present in the DOM array is ignored and linkUrl and linkText is
     *    always used!
     */
	_PRIV_anchorElementBuilder: function(elementDOM, linkUrl, linkText, linkTarget, onClickHandler, alwaysA, suppressUserDefinedLinkData) {
			var widget = this;	// This is so that widget params can be accessed in the closure
			var cssPrefs = widget._PRIV_widgetFormat.base_css; // COMPRESSION: local variable to ensure better code compression!
			return widget._PRIV_buildElementContainer(
								linkText,
								elementDOM,
								function(eltData, newElt, params) { 
									if (!newElt)
										newElt = widget._PRIV_createElement('a', cssPrefs.link_class, cssPrefs.link_style);  // generic style
                  
                  if ((newElt.tagName != 'A') && !alwaysA) {
                    newElt.innerHTML = eltData;
                  }
                  else {
                    newElt.target = linkTarget;
                    newElt.onclick = onClickHandler;
                    newElt.href = (!suppressUserDefinedLinkData && params && params.url) ? params.url : linkUrl;
                    var link = (!suppressUserDefinedLinkData && params && params.text) ? params.text : eltData;
                    if (typeof(link) == "object") // if we have been passed a html element, append it as a child!
                      newElt.appendChild(link);
                    else
                      newElt.innerHTML = link;
                  }

									return newElt;
								}
						);
		},

    /**
     * This is the default (most common) anchor element builder and has the following behavior
     * 1. If the last array element of elementDOM is not an A, it is ignored -- an A is always built!
     * 2. If the last array element of elementDOM is an A, the link url and link text it provides will be picked instead of linkUrl and linkText
     **/
	_PRIV_defaultAnchorElementBuilder: function(elementDOM, linkUrl, linkText, onClickHandler) {
		var widget = this;
		var linkTarget = widget._PRIV_widgetFormat.base_css.link_target;
    return widget._PRIV_anchorElementBuilder(elementDOM, linkUrl, linkText, linkTarget, onClickHandler, true, false);
  },

	_PRIV_addSeparator: function(container, sep) {
			if (sep) {
					// Process "\n" newline elements at the beginning and strip them off the separator
				if (sep.substring(0,1) == '\n') {
					container.appendChild(document.createElement('br'));
					sep = sep.substring(1);
				}
				if (sep)
					container.appendChild(document.createTextNode(sep));
			}
		},

  _PRIV_addRating: function(newElt, rating, showStars, starsDir, trailingString, reviewsPageUrl) {
      var widget = this;

      /* Create a rating element: stars + string, or just string */
      var ratingElt = widget._PRIV_createElement('span', '', '');
      if (rating) {
        if (showStars) {
		      var pngs = widget._PRIV_widgetFormat.content.png_stars;
            // NOTE: Added 'float:none;' to override any float settings on the target site
            // (Ex: http://www.pbs.org/newshour/vote2008/reportersblog/2008/10/as_candidates_grapple_with_eco.html)
          var ratingImg = widget._PRIV_createImage(widget._PRIV_baseUrl + _GLOB_relativeStarsDir + starsDir + _GLOB_getRatingImageFile(rating, pngs),
                                                   rating + ' rating',
                                                   widget._PRIV_widgetFormat.base_css.stars_img_class,
                                                   widget._PRIV_widgetFormat.base_css.stars_img_style);

            // Add a text rating information besides the trustometer
            // Use a span so that trailing string can have special chars (&raquo;, etc.)
          var ratingString = widget._PRIV_createElement('span', '', '');
          ratingString.innerHTML = ' ' + rating + trailingString;

            // Append the image and the text
          ratingElt.appendChild(ratingImg);
          ratingElt.appendChild(ratingString);
        }
        else {
            // set inner html of the span rather than creating a text node 
            // so that trailing string can have special chars
          ratingElt.innerHTML = rating + trailingString;
        }
      }
      else {
          // We end up here for stories without sufficient reviews, and where the story's source
          // is not in the database!  So, display 'not enough reviews' text.
        ratingElt.appendChild(document.createTextNode('No Rating'));
      }

      /* If necessary, hyperlink the rating element to the target review url */
      if (!newElt) {
        newElt = ratingElt;
      }
      else {
        if (newElt.tagName == 'A') {
          newElt.href   = reviewsPageUrl;
          newElt.target = widget._PRIV_widgetFormat.base_css.link_target;
        }
        newElt.appendChild(ratingElt);
      }

      return newElt;
    },

  _PRIV_hideElt: function(eltName) { 
        // Either (1) hide is set to true for that element
        // OR     (2) we have hide-defaults specified for the element with a true value
        //            and there is no override hide value specified for that element with a false value
      return    (_GLOB_defined(this._PRIV_hideElts) && this._PRIV_hideElts[eltName])
             || (    (typeof _NTW_defaultHides != 'undefined') && _GLOB_defined(_NTW_defaultHides[eltName]) && _NTW_defaultHides[eltName]
                 && !(_GLOB_defined(this._PRIV_hideElts) && _GLOB_defined(this._PRIV_hideElts[eltName]) && !this._PRIV_hideElts[eltName]))
    },

  _PRIV_eval_condition: function(d, cond) { return eval("d." + cond); },

  _PRIV_elementAbsent: function(dataObj, eltName) { return eltName && (!this._PRIV_eval_condition(dataObj, eltName) || this._PRIV_hideElt(eltName)); },

	_PRIV_addDataElement: function(dataObj, eltParams, containerDIV) {
				// record the widget so that closures in this method have access to the widget params.
			var widget = this;										// COMPRESSION: copy a reference to the widget to enable better code compression
		  var contentPrefs = widget._PRIV_widgetFormat.content;	// COMPRESSION: local variable to ensure better code compression!
			var cssPrefs = widget._PRIV_widgetFormat.base_css; 		// COMPRESSION: local variable to ensure better code compression!
			var baseUrl = widget._PRIV_baseUrl;					// COMPRESSION: local variable to ensure better code compression!

				// Don't do anything if the widget element is defined in the data object, but the data value for the element is empty!
			var elt = eltParams.element;
			if (elt.match(/review\./)) {
        var f = elt.replace("review.", "");
        if (_GLOB_defined(dataObj.review[f]) && !dataObj.review[f])
          return;
      }
      else {
        if (_GLOB_defined(dataObj[elt]) && !dataObj[elt])
          return;
      }

        // Either the required data field is absent, or it has been hidden!
      if (widget._PRIV_elementAbsent(dataObj, eltParams.if_present))
        return;

				// If we have been asked to hide this element, return!
      if (this._PRIV_hideElt(elt))
				return;

				// If there aren't sufficient reviews for this story, and there
				// is a 'see reviews' story element to be displayed, suppress it!
			if ((elt == 'see_reviews') && widget._PRIV_notEnoughReviewsForStory)
				return;

			/*
			 * NOTE: since the checks above this comment essentially bypass the elements,
			 * any separator attached to them also gets bypassed!  So, if a "\n" is attached to
			 * them, the next element won't start on a new line as might be expected.
			 *
			 * Rather than trying to build smarts into this code to handle these situations,
			 * we are shifting responsibility to the writer of the widget formats.
			 * 
			 * A simple way of handling the "\n" situation above is to define an empty element
			 *       { element : '', separator : '\n', dom : [] }
			 * in the widget spec as above -- this guarantees that a <br/> will be generated at that spot!
			 */

				// Add the prefix separator -- if a required element is absent, the prefix is ignored!
			if (eltParams.prefix && !widget._PRIV_elementAbsent(dataObj, eltParams.prefix_if_present))
				widget._PRIV_addSeparator(containerDIV, eltParams.prefix);

				// The following two values are defined ONLY for story data objects, not for header or footer meta-data objects
				// For story data objects, 'id' property would be defined
			var storyReviewsUrl = '';
			var storyPageUrl = '';
			var reviewUrl       = '';
      var reviewHandler   = '';
      var trackingCode    = widget._PRIV_widgetFormat.content.tracking_code;
			if (dataObj && _GLOB_defined(dataObj.id)) {
        storyPageUrl    = baseUrl + 'stories/' + dataObj.id;
        storyReviewsUrl = storyPageUrl + '?ref=' + trackingCode;
				reviewUrl       = storyPageUrl + '/toolbar?ref=' + trackingCode;
				reviewHandler   = function() { var w = _GLOB_Popup.open(reviewUrl + '&popup=true'); w.focus(); }
			}

			var linkTarget = '';
			var rootElt = '';
				// Now process the DOM specs. of the story element
			var eltDOM = !_GLOB_defined(eltParams.dom) ? [] : eltParams.dom;
			switch (elt) {
        case 'review.rating':
				  reviewUrl = baseUrl + 'stories/' + dataObj.id + '/reviews/' + dataObj.review.id;
					rootElt = widget._PRIV_buildElementContainer(
							dataObj.review,
							eltDOM,
							function(dataObj, newElt) { return widget._PRIV_addRating(newElt, dataObj.rating, true, contentPrefs.stars_dir, '', reviewUrl); }
					);
					break;

        case 'review.see_it':
				  reviewUrl = baseUrl + 'stories/' + dataObj.id + '/reviews/' + dataObj.review.id;
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, reviewUrl, "See Review &raquo;", '');
					break;

        case 'rating_nostars':
					rootElt = widget._PRIV_buildElementContainer(
							dataObj,
							eltDOM,
							function(dataObj, newElt) { return widget._PRIV_addRating(newElt, (numReviews == 0) ? 0 : dataObj.rating, false, '', '', storyReviewsUrl); }
					);
					break;

				case 'rating':
					rootElt = widget._PRIV_buildElementContainer(
							dataObj,
							eltDOM,
							function(dataObj, newElt) {
								var starsDir  = contentPrefs.stars_dir;

								/* If there aren't enough reviews, use gray rating */
                var numReviews  = 1*dataObj.num_reviews; // num_reviews is currently passed in as a string!!  multiplying by 1 converts it to an integer
								if (numReviews < (1*widget._PRIV_metaData.min_reviews)) {  // Need the multiplication by 1 to convert string to numeric value!
									 starsDir = contentPrefs.gray_stars_dir;
								}

								var storyRating = (numReviews == 0) ? 0 : dataObj.rating;
								return widget._PRIV_addRating(newElt, storyRating, contentPrefs.show_stars, starsDir, '', storyReviewsUrl);
							}
					);
					break;

				case 'source':
            /**
             * 1. By default, we will always hyperlink the source back to the listing page
             * 2. We are setting 'alwaysA' to false.  So, if the last element is not an 'a' element, it won't be linked back!
             * 3. We are setting 'suppressUserDefinedLinkData to 'false'.  This allows the widget format to override the default linking behavior.
             *    For example, some partners might want it linked back to their site!
             **/
          var src = dataObj.source;
					linkTarget = cssPrefs.link_target;
          rootElt = src.is_public ? widget._PRIV_anchorElementBuilder(eltDOM, baseUrl + 'sources/' + src.id, src.name, linkTarget, '', false, false)
                                  : widget._PRIV_defaultTextElementBuilder('', src.name);
					break;

				case 'title':
            /* We are setting 'alwaysA' to true -- so, if the last eltDOM entry is not an 'A', it will be ignored
             * Additionally, we are suppressing any user provided link text & link url -- titles are always linked to the story url -- no exceptions! */
				  linkTarget = cssPrefs.link_target; // Toolbar stories always open in a new window!
					//if (!widget._PRIV_amSignedIn || !_GLOB_defined(linkTarget)) 
          if (dataObj.source && dataObj.source.framebuster)
					  rootElt = widget._PRIV_anchorElementBuilder(eltDOM, dataObj.url, _GLOB_trim(dataObj.title, contentPrefs.title_max_length), '', reviewHandler, true, true);
          else
            rootElt = widget._PRIV_anchorElementBuilder(eltDOM, reviewUrl, _GLOB_trim(dataObj.title, contentPrefs.title_max_length), linkTarget, '', true, true);
					break;

				case 'num_reviews':
          var numReviews = dataObj.num_reviews;
          var minReviews = widget._PRIV_metaData.min_reviews;
          var numReviewsTxt = (numReviews == 0) ? "See&nbsp;Info" : ((numReviews == 1) ? "See&nbsp;Review" : ((numReviews < minReviews) ? "See&nbsp;Reviews" : numReviews + " Reviews"));
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, storyReviewsUrl, numReviewsTxt + " &raquo;", '');
					break;

        case 'like_it':
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, storyPageUrl + "/save?ref=" + trackingCode, 'Like', '');
          break;

				case 'see_reviews':
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, storyReviewsUrl, 'See&nbsp;Reviews', '');
					break;

				case 'review_it':
					linkTarget = cssPrefs.link_target;
					//if (!widget._PRIV_amSignedIn || !_GLOB_defined(linkTarget)) 
          if (dataObj.source && dataObj.source.framebuster)
					  rootElt = widget._PRIV_anchorElementBuilder(eltDOM, dataObj.url, 'Review&nbsp;It', '', reviewHandler, true, false); // open story in same window -- so, ignoring linkTarget
          else
            rootElt = widget._PRIV_anchorElementBuilder(eltDOM, reviewUrl + "&go=review", 'Review&nbsp;It', linkTarget, '', true, false);
					break;

					/* The following 5 cases are for the header */
				case 'source_name':
				case 'title_prefix':
				case 'listing_topic':
				case 'listing_type':
				case 'sources_type':
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, dataObj.listing_url, dataObj[elt], '');
					break;

				case 'hdr_story_type':
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, dataObj.listing_url, dataObj.hdr_story_type, '');
					break;

          /* The following 2 cases are used for news hunts */
				case 'newshunt_title':
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, widget._PRIV_newsHuntElts.url, widget._PRIV_newsHuntElts.title, '');
					break;

				case 'newshunt_desc':
					var desc   = widget._PRIV_defaultTextElementBuilder(eltDOM, widget._PRIV_newsHuntElts.description);
          var signup = widget._PRIV_defaultAnchorElementBuilder('', widget._PRIV_newsHuntElts.url, '  Sign up', '');
          var rest   = widget._PRIV_defaultTextElementBuilder('', ' to start reviewing.');
          rootElt = widget._PRIV_createElement('div', '', '');
          rootElt.appendChild(desc);
          rootElt.appendChild(signup);
          rootElt.appendChild(rest);
					break;

				case 'more_stories': /* Footer */
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, dataObj.listing_url, 'More &raquo;', '');
					break;

				case 'help': /* Footer */
						/* NOTE: This is a popup!  So, do not provide any link target! */
					rootElt = widget._PRIV_anchorElementBuilder(eltDOM, 'javascript:void(0)', 'How we pick these', '', function() { _GLOB_Popup.open(baseUrl + 'help/faq#how_we_pick_stories'); }, true, false);
					break;

				case 'submit_story': /* Footer */
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, baseUrl + 'submit', 'Post a story', '');
					break;

				case 'get_widget': /* Footer */
            /* Member widgets have #picks and #reviews in them -- replace it with /picks or /reviews */
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, baseUrl + 'widgets?url='+dataObj.listing_url.substring(baseUrl.length-1).replace("#", "/"), 'Get this widget', '');
					break;

        case 'signup': /* Footer */
					rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, baseUrl + 'partners/feeds/widget', 'Sign up', '');
					break;

			 /* FIXME: 'subject', 'topics' not yet supported */

				case 'date':
					rootElt = widget._PRIV_defaultTextElementBuilder(eltDOM, _GLOB_formatDate(dataObj.date, contentPrefs.date_format));
					break;

        case 'review.note':
					rootElt = widget._PRIV_defaultTextElementBuilder(eltDOM, _GLOB_trim(dataObj.review.note, contentPrefs.quote_max_length));
					break;

        case 'review.comment':
					rootElt = widget._PRIV_defaultTextElementBuilder(eltDOM, _GLOB_trim(dataObj.review.comment, contentPrefs.quote_max_length));
					break;

        case 'review.links':
          if (dataObj.review.links && dataObj.review.links.length > 0) {
            rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, dataObj.review.links[0].url, dataObj.review.links[0].title, '');
              // If we are adding a second link, duplicate the prefix and suffix!
            if (dataObj.review.links && dataObj.review.links.length > 1) {
              containerDIV.appendChild(rootElt);
              if (eltParams.suffix && !widget._PRIV_elementAbsent(dataObj, eltParams.suffix_if_present))
                widget._PRIV_addSeparator(containerDIV, eltParams.suffix);
              if (eltParams.prefix && !widget._PRIV_elementAbsent(dataObj, eltParams.prefix_if_present))
                widget._PRIV_addSeparator(containerDIV, eltParams.prefix);
              rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, dataObj.review.links[1].url, dataObj.review.links[1].title, '');
            }
          }
					break;

				case 'quote':
					rootElt = widget._PRIV_defaultTextElementBuilder(eltDOM, _GLOB_trim(dataObj.quote, contentPrefs.quote_max_length));
					break;

				case 'submitted_by':
				case 'last_reviewer':
					rootElt = widget._PRIV_defaultTextElementBuilder(eltDOM, dataObj[elt].name);
					break;

        case 'image':
          var img = widget._PRIV_createImage(baseUrl + eltParams.source, '', '', 'display:inline;float:none;border:none;');
          rootElt = widget._PRIV_defaultAnchorElementBuilder(eltDOM, '', img, '');
          break;

          /* Default case:
           * 1. for 'authors', 'story_type', 'num_reviews', 'timespan', 'digg_tweet_info', 'via_credit', pick dataObj[elt]
           * 2. for everything else, where dataObj[elt] is undefined, just render the element name itself as
           *    innerHTML value of the last DOM array entry.  If DOM array is empty, the element name is rendered as plain text! */
				default:
          var eltData = _GLOB_defined(dataObj[elt]) ? dataObj[elt] : elt;
					rootElt = widget._PRIV_buildElementContainer(
                      eltData,
											eltDOM,
											function(eltData, newElt, params) {
														// If there isn't any DOM, the element name is rendered verbatim!
												 if (!newElt) {
														newElt = document.createTextNode(eltData);
												 }
														// If it is not a 'a' element, it becomes inner html of the last dom element.
												 else if (newElt.tagName != 'A') {
														newElt.innerHTML = eltData;
												 }
														// If it is an 'a' element, the element name becomes the link text, unless the
														// dom element itself provides the link text in which case, the element name is ignored!
												 else {
															// If params.url is undefined, it is a BAD FORMAT!  Just link this element back to the main site!
														newElt.href      = (params && params.url) ? params.url : baseUrl;
														newElt.innerHTML = (params && params.text) ? params.text : eltData;
														newElt.target    = cssPrefs.link_target;

                              // Set the generic link style if the widget format doesn't provide any style for this link!
														if (!params.clazz && !params.style)
															 widget._PRIV_setStyle(newElt, cssPrefs.link_class, cssPrefs.link_style);
												 }
												 return newElt;
											}
										);
					break;
			}

			if (rootElt)
				containerDIV.appendChild(rootElt);

				// Add the suffix separator -- if a required element is absent, the suffix is ignored!
			if (eltParams.suffix && !widget._PRIV_elementAbsent(dataObj, eltParams.suffix_if_present))
				widget._PRIV_addSeparator(containerDIV, eltParams.suffix);
		},

  _PRIV_buildChildren: function(dataObj, childFormats, parentDIV) {
				// Now, process the format for the section and build the core section content
			for (var j = 0; j < childFormats.length; j++) {
        var eltFormat = childFormats[j];
        if (eltFormat.element != 'div_dom_tree') { // COMMON CASE
          this._PRIV_addDataElement(dataObj, eltFormat, parentDIV);
        }
        else { // Request for a DOM tree here!
          var subTreeDIV = this._PRIV_createElement('div', eltFormat.clazz, eltFormat.style);
          this._PRIV_buildChildren(dataObj, eltFormat.children, subTreeDIV);
          parentDIV.appendChild(subTreeDIV);
        }
      }
  },
	
		// This method builds a specific section of the widget
	_PRIV_buildWidgetSection: function(widgetDIV, section, dataObj, initFunc) {
			var widgetFormat = this._PRIV_widgetFormat;	// COMPRESSION: local variable to ensure better code compression!

				// Build the div and set base style
			var secDIV = this._PRIV_createElement('div', widgetFormat.base_css[section + '_class'], widgetFormat.base_css[section + '_style']);

				// Initialize it as necessary
			if (initFunc) 
				initFunc(secDIV);

        // Build children!
      this._PRIV_buildChildren(dataObj, widgetFormat[section + '_format'], secDIV);

				// Add the completely-built div to the widget!
			widgetDIV.appendChild(secDIV);
		},

		// Link the branding element to the site's base url
  _PRIV_getLinkedBranding: function(linkedElt) {
				// Link it to the base url
			var widget = this;						// COMPRESSION: copy a reference to the widget to enable better code compression
			var link = widget._PRIV_createElement('a', '', 'color:#222;font-family:arial,helvetica,sans-serif;font-size:11px;text-decoration:none;');
			link.href = widget._PRIV_baseUrl;
			link.target = widget._PRIV_widgetFormat.base_css.link_target;
			link.appendChild(linkedElt); 

			return link;
		},

		// Generate the root widget div
  _PRIV_generateWidgetDiv: function() {
				// local vars. to ensure better code compression!
			var widget = this;											// COMPRESSION: copy a reference to the widget to enable better code compression
		  var contentPrefs   = widget._PRIV_widgetFormat.content;	// COMPRESSION: local variable to ensure better code compression!
		  var cssPrefs       = widget._PRIV_widgetFormat.base_css;// COMPRESSION: local variable to ensure better code compression!
			var baseUrl 			 = widget._PRIV_baseUrl;		// COMPRESSION: local variable to ensure better code compression!
			var widgetMetaData = widget._PRIV_metaData;		// COMPRESSION: local variable to ensure better code compression!

				// Construct a top-level branding div that will have header branding, footer branding, and the actual widget.
			var brandingDIV = widget._PRIV_createElement('div', cssPrefs.base_class, cssPrefs.base_style);

					// Create the logo! IMPORTANT: set 'display:inline;' so that it cannot be turned off!
          // NOTE: Added 'float:none;' to override any float settings on the target site
			var siteLogo = contentPrefs.site_logo;
			if (siteLogo) {
        if (typeof(widgetMetaData.local_site) != 'undefined' && widgetMetaData.local_site)
          siteLogo = siteLogo.replace(/logos\/socialnews-logo/, "logos/" + widgetMetaData.local_site + "-socialnews-logo");
				brandingDIV.appendChild(widget._PRIV_getLinkedBranding(widget._PRIV_createImage(baseUrl + siteLogo, 'SocialNews.com ', '', 'display:inline;float:none;padding:5px;border:none;')));
      }

				// Create the top level widget div!
			var widgetDIV = widget._PRIV_createElement('div', '', '');

				// Generate the header -- pass in the file meta-data, no initialization!
			if (contentPrefs.header)
				widget._PRIV_buildWidgetSection(widgetDIV, 'header', widgetMetaData, '');

        // Handle access-denied scenarios!
      if (typeof(_NTW_access_denied) != 'undefined') {
        var msgDIV = widget._PRIV_createElement('div', '', 'style:clear:both;padding:15px;color:black');
        msgDIV.innerHTML = _NTW_access_denied;
        widgetDIV.appendChild(msgDIV);
      }
      else {
          // Generate HTML for stories
        var count          = 0;
        var stories        = widget._PRIV_stories;
        var numStories     = stories.length;
        var numReqdStories = contentPrefs.num_stories;
        for (var i = 0; i < numStories; i++) {
          if ((count == numReqdStories) || !stories[i].id) // We are done!
            break;

          var storyData = stories[i];

            // check if this story does not have any displayable rating info
          widget._PRIV_notEnoughReviewsForStory = ((1*storyData.num_reviews) < (1*widgetMetaData.min_reviews)) && !storyData.source.rating;

            // Generate the next story -- pass in the story data, no initialization
          widget._PRIV_buildWidgetSection(widgetDIV, 'story', storyData, '');
          count++;
        }

          // Add a message for empty / partially-empty widgets!
        if (numStories < numReqdStories) {
          var msg       = '<br style="clear:both"/>' + ((numStories == 0) ? 'No stories' : 'Not enough stories');
          var linkStyle = cssPrefs.link_class ? (' class="' + cssPrefs.link_class + '"') : (' style="' + cssPrefs.link_style + '"');

            // FIXME: hacking empty widget message -- ideally this should be
            // part of the widget format -- not hardcoded in this fashion!
            // But, what to do ... such are the conflicts of programming.
          var listingUrl = widgetMetaData.listing_url;
          if (listingUrl.search("members.*picks") != -1) {
             msg += ' were picked.<br/>';
             msg += 'To find out more about picks, check our <a' + linkStyle + ' href="' + baseUrl + 'help/faq/member#member_picks">FAQ</a>.';
          }
          else {
              // Construct the URL for the story reviews page for this story listing
            var u = listingUrl.replace(/(most_trusted)(_\d+)?|recent_reviews/, 'most_recent');
            msg += ' were rated in this category recently!<br/>';
            msg += '<div>To add more stories to this listing:</div>';
            msg += '<ul style="margin:0"><li><a' + linkStyle + ' href="' + baseUrl + 'submit">Post a story</a></li><li><a' + linkStyle + ' href="' + u + '">Rate stories</a></li></ul>';
          }

            // Message
          var msgDIV = widget._PRIV_createElement('div', '', 'style:clear:both;padding:0 25px 15px 25px');
          msgDIV.innerHTML = msg;

            // Append to the widget!
          widgetDIV.appendChild(msgDIV);
        }
      }

				// Create a footer if necessary -- pass in the file metadata
			if (contentPrefs.footer)
				widget._PRIV_buildWidgetSection(widgetDIV, 'footer', widgetMetaData, '');

				 // Add the core widget div!
			brandingDIV.appendChild(widgetDIV);

				// Add footer branding if the site logo has been suppressed!
				// Assign it its own background and color so that it show up on all backgrounds!
			if (!siteLogo) {
				var d = widget._PRIV_createElement('div', '', 'background:#fff;text-align:left;padding:0 0 2px 4px;');
				d.innerHTML = 'Reviews by <span style="font-weight:bold;">SocialNews</span>';
				brandingDIV.appendChild(widget._PRIV_getLinkedBranding(d));
			}

				// Record the div
			widget.rootDIV = brandingDIV;

			return brandingDIV;
		},

		// Get the <script> tag element corresponding to this script
	_PRIV_getScriptElement: function(scriptUrl) {
			var scripts = document.getElementsByTagName('script');
			for (var i = 0; i < scripts.length; i++) {
          // IE7 doesn't expand relative urls to absolute urls, whereas FF does
          // So, just normalize everything to relative urls, without a leading "/"
				var scriptSrc = scripts[i].src.replace(/http:\/\/www./, 'http://').replace(/beta./, '').replace(/preview./, '').replace(this._PRIV_baseUrl, "").replace(/^\//, "");
          // Legacy widgets come with "js/" and new widgets come with "javascripts/" 
				if ((scriptSrc == "js/" + scriptUrl) || (scriptSrc == "javascripts/" + scriptUrl)) {
					return scripts[i];
        }
			}

			return undefined;
		},

		// Replace 'replNode' with a generated widget div
  installOver: function(replNode) { replNode.parentNode.replaceChild(this._PRIV_generateWidgetDiv(), replNode); },

		// Get the <script> tag element for this script, and replace it with the generated widget
  install: function() { 
          // IE7 doesn't expand relative urls to absolute urls, whereas FF does
          // So, just normalize everything to relative urls, without a leading "/"
			var scriptUrl = 'render_widget.js';
      //Uncomment the next line when using the uncompressed version of the js code during testing.
			//var scriptUrl = 'render_widget.uncompressed.js';
			this.installOver(this._PRIV_getScriptElement(scriptUrl));
		},

		// Replace the old widget DIV with a new generated widget
  refresh: function() { this.installOver(this.rootDIV); }
}

// Immediate rendering can be prevented by setting a flag to block it!
var _ntw_widget = '';
if ((typeof _NTW_libraryMode == 'undefined') || !_NTW_libraryMode) {
		// Construct the widget
  var w = new _NTW_Widget(_NTW_stories, _NTW_file_metadata, _NTW_widget_defaults); 

 		// Set up user preferences next -- and clear them right away
		// so that multiple widgets on the page don't conflict with each other
 	if (typeof _NTW_hideElts != 'undefined') {
 	  w.setHideElts(_NTW_hideElts);
	  _NTW_hideElts = undefined;
	}

 	if (typeof _NTW_newshunt!= 'undefined') {
 	  w.setNewsHuntElts(_NTW_newshunt);
	  _NTW_newshunt= undefined;
	}

  if (typeof _NTW_width != 'undefined') {
    w.setWidth(_NTW_width);
	  _NTW_width = undefined;
  }

 	if (typeof _NTW_numStories != 'undefined') {
    w.setNumStories(_NTW_numStories);
	  _NTW_numStories = undefined;
  }	

 	if (typeof _NTW_trackingCode != 'undefined') {
    w.setTrackingCode(_NTW_trackingCode);
	  _NTW_trackingCode = undefined;
	}

		// Install now!
	w.install();
	_ntw_widget = w;	// Make available this widget externally via the '_ntw_widget' variable
}
