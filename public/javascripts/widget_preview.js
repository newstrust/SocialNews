/**
 * Widget Preview internals
 */
var defaultNumStories = 5;
var widgetFormat = 'default';
var curr_member_slug = '';
var iframeEltStyle = '';	/* style setting of the widget preview iframe */
var jsPreviewWidget = '';	/* the preview js widget */
var widgetType = '';

/* Supported widget types */ 
var allWidgetTypes = ['topic', 'member', 'source'];

/* ***********************************************
 * Default settings for the different widget types
 * 1. What checkboxes are displayed for different widgets? *
 * 2. Check box defaults for diff. widget types -- these checkboxes will be left unchecked by default
 * 3. The default widget theme/format 
 * *********************************************** */
var widgetTypeDefaults = {
  topic : {
    widgetCheckBoxes  : { 'source': 1, 'stars': 1, 'rating': 1, 'review.note': 0, 'review.comment': 0, 'review.links': 0 },
    uncheckedDefaults : { },
    widgetFormat      : 'default'
  },
  member : {
    widgetCheckBoxes  : { 'source': 1, 'stars': 0, 'rating': 0, 'review.note': 1, 'review.comment': 1, 'review.links': 1 },
    uncheckedDefaults : { 'date': 1, 'authors': 1, 'quote': 1, 'like_it': 1, 'review.comment': 1, 'review.links': 1 },
    widgetFormat      : 'member_widget'
  },
  source : {
    widgetCheckBoxes  : { 'source': 0, 'stars': 1, 'rating': 1, 'review.note': 0, 'review.comment': 0, 'review.links': 0 },
    uncheckedDefaults : { 'date': 1, 'like_it': 1 },
    widgetFormat      : 'source_widget'
  }
};

/* Story elements across all widgets */
var storyElts  = ['date', 'source', 'stars', 'rating', 'story_type', 'authors', 'quote', 'num_reviews', 'review_it', 'like_it', 'review.note', 'review.comment', 'review.links'];

function getObj(objId)  { return document.getElementById(objId); } 
function hide(obj)      { obj.style.display = 'none'; }
function show(obj)      { obj.style.display = 'block'; }
function showObj(objId) { show(getObj(objId)); }
function hideObj(objId) { hide(getObj(objId)); }
function showParentOfObj(objId) { show(getObj(objId).parentNode); }
function hideParentOfObj(objId) { hide(getObj(objId).parentNode); }
function setSelection(selId, index) { getSelectObj(selId).selectedIndex = index; }
function isPicksWidget() { return (widgetType == 'member') && (getSelectedValue('member_widgetType') == "picks"); }
function isMynewsWidget() { return (widgetType == 'member') && (getSelectedValue('member_widgetType') == "mynews"); }
function useDefaultFormatForMember() { return (isPicksWidget() || isMynewsWidget()); }

function getSelectObj(selId)
{
	var divObj   = getObj(selId);
	var children = divObj.childNodes;
	for (i = 0; i < children.length; i++) {
	   if (children[i].nodeName.toLowerCase() == 'select')
	      return children[i];
	}
	return null;
}

function getSelectedValue(selId)
{
	var selObj = getSelectObj(selId);
	return (selObj.disabled) ? "" : selObj.options[selObj.selectedIndex].value;
}

function getRadioVal(radioName)
{
	var allRadio = document.getElementsByTagName('input');
	for (i = 0; i < allRadio.length; i++) {
	   if ((allRadio[i].name == radioName) && (allRadio[i].style.display != 'none') && allRadio[i].checked) {
	      return allRadio[i].value;
	   }
	}
	return "";
}

function setRadioVal(radioName, val)
{
	var allRadio = document.getElementsByTagName('input');
	for (i = 0; i < allRadio.length; i++) {
	   if ((allRadio[i].name == radioName) && (allRadio[i].style.display != 'none') && allRadio[i].value == val) {
	      allRadio[i].checked = true;
        return;
	   }
	}
}

function setEltStyle(elt, styleText)
{
       // this is for IE7 and not sure which other browsers
  if (elt.style.setAttribute)
    elt.style.setAttribute('cssText', styleText);
       // this is for FF, Safari, and not sure which other browsers
  else
    elt.setAttribute('style', styleText); 
}

function updateAvailableWidgetFormats()
{
    // Nothing to do if the More Options check box is not open
	if (getObj('js_checkboxes').style.display == 'none')
    return;

  if (widgetType == 'topic') {
    showObj('js_widgetTheme');
    hideObj('unbranded_theme');
    showObj('unstyled_theme');
  }
  else if (widgetType == 'source') {
    hideObj('js_widgetTheme');
  }
  else if (widgetType == 'member') {
      // Picks get the default & unbranded themes, others get none
    if (useDefaultFormatForMember()) {
      showObj('js_widgetTheme');
      hideObj('unstyled_theme');
      showObj('unbranded_theme');
    }
    else {
      hideObj('js_widgetTheme');
    }
  }
}

function changePageForWidgetType()
{
	showObj('js_disp_options');
	showObj('preview_div');

    // Show appropriate widget type opts
	for (i = 0; i < allWidgetTypes.length; i++)
    (widgetType == allWidgetTypes[i]) ? showObj(allWidgetTypes[i] + '_widget_opts') : hideObj(allWidgetTypes[i] + '_widget_opts')

    // Reset check boxes
  var useDefaultWidget = useDefaultFormatForMember();
  var cboxes = useDefaultWidget ? widgetTypeDefaults['topic'].widgetCheckBoxes  : widgetTypeDefaults[widgetType].widgetCheckBoxes;
  var ucdefs = useDefaultWidget ? widgetTypeDefaults['topic'].uncheckedDefaults : widgetTypeDefaults[widgetType].uncheckedDefaults;
	for (i = 0; i < storyElts.length; i++) {
		var elt = storyElts[i];
    var eltId = 'show:' + elt;
    ((typeof cboxes[elt] == 'undefined') || (cboxes[elt] == 1)) ? showParentOfObj(eltId) : hideParentOfObj(eltId);
		getObj(eltId).checked = (typeof ucdefs[elt] == 'undefined');
  }

  updateAvailableWidgetFormats();
}

function showWidget(wt)
{
  widgetType = wt;
  resetDefaultWidgetFormat();
  changePageForWidgetType();
	showPreview();
}

function updateWidget(wt)
{
  widgetType = wt;

    // For member widgets, have to update everything because review and picks require different defaults for the checkboxes.
    // For topic & source widgets, no need to update the checkboxes.  So, simply update the preview
  if (wt == 'member')
    showWidget(wt);
  else
    showPreview();
}

function showMemberReviews(slug)
{
  if (slug == '') {
    curr_member_slug = '';
    showObj('member_ac');
  }
  else {
    curr_member_slug = slug;
    hideObj('member_ac');
  }
  updateWidget('member');
}

function setWidgetFormat(format, unstyled)
{
	if (unstyled)
		getObj('unstyled_help').style.display = 'inline';
	else
		hideObj('unstyled_help');

    // No unbranded format for non-member-picks widgets
  if (!useDefaultFormatForMember() && (format == 'unbranded'))
    return;

	widgetFormat = format; 
	showPreview(); 
}

function resetDefaultWidgetFormat()
{
  widgetFormat = useDefaultFormatForMember() ? widgetTypeDefaults['topic'].widgetFormat : widgetTypeDefaults[widgetType].widgetFormat;
  setRadioVal("widget_theme", widgetFormat);
}

function toggleWidgetThemeCheckBoxes()
{
	var cbs = getObj('js_checkboxes');
	if (cbs.style.display == 'none') {
		cbs.style.display = 'block';
    updateAvailableWidgetFormats();
		getObj('js_moreOptsArrow').src = '/images/ui/disclosuretri-open.gif';
	}
	else {
		cbs.style.display = 'none';
		hideObj('js_widgetTheme');
		getObj('js_moreOptsArrow').src = '/images/ui/disclosuretri-shut.gif';
	}
}

function topicSelectionIsASubject(selObjId) { return getSelectObj(selObjId).selectedIndex < (1+numSubjects); }

var timer;	// Global variable so that it can be cleared out!

function listingRequiresDateWindow(listingType) {
  return (listingType == 'most_trusted') || (listingType == 'least_trusted');
}

// subjects/world/most_recent/news/mainstream
// members/david-fox/reviews
// sources/washington-post/most_recent
function getBaseWidgetName()
{
  var baseWidgetName = '';
  if (widgetType == 'member') {
    var slug = curr_member_slug;
    if (!slug)
      slug = getObj('member_slug').value;
    if (slug == '')
      return '';

    var rType = getSelectedValue('member_widgetType')
    baseWidgetName = "members/" + slug + "/" + rType;

      // For picks/mynews, we use the default widget format for stories
	  widgetFormat = useDefaultFormatForMember() ? getRadioVal("widget_theme") : widgetTypeDefaults[widgetType].widgetFormat;
  }
  else if (widgetType == 'source') {
	  widgetFormat = widgetTypeDefaults[widgetType].widgetFormat;

    var slug = getObj('source_slug').value;
    if (slug == '')
      return '';

    baseWidgetName = "sources/" + slug;

    var listingType = getSelectedValue('src_listingType');

      // Special code to support date-windows for top-rated listings
    if (listingRequiresDateWindow(listingType)) {
      showObj('src_dateWindow');

      var numDays = getObj('src_dateWindowVal').value;
      if (numDays && (numDays != "30"))
        listingType = listingType + '_' + numDays;
    }
    else {
      hideObj('src_dateWindow');
    }

    if (listingType)
      listingType = "/" + listingType;

    var contentType = getSelectedValue('src_contentType');
    if (contentType)
      contentType = "/" + contentType;

    var topic       = getSelectedValue('src_topic');
    if (topic == 'all_stories')
      baseWidgetName += listingType + contentType;
    else if (topicSelectionIsASubject('src_topic'))
      baseWidgetName += "/subjects/" + topic + listingType + contentType;
    else if (topic != '')
      baseWidgetName += "/topics/" + topic + listingType + contentType;
  }
  else {
	  widgetFormat = getRadioVal("widget_theme");

    var topic       = getSelectedValue('content_topic');
    var listingType = getSelectedValue('content_listingType');
    var media       = getSelectedValue('content_mediaType');
    var contentType = getSelectedValue('content_contentType');

      // Special code to support date-windows for top-rated listings
    if (listingRequiresDateWindow(listingType)) {
      showObj('content_dateWindow');

      var numDays = getObj('content_dateWindowVal').value;
      if (numDays)
        listingType = listingType + '_' + numDays;
    }
    else {
      hideObj('content_dateWindow');
    }

    if ((topic == 'None') || (listingType == 'None') || (media == 'None') || (contentType == 'None'))
       return '';

    if (listingType)
      listingType = "/" + listingType;

    if (contentType)
      contentType = "/" + contentType;

    if (media)
      media = "/" + media;
    if (topic == 'all_stories') {
      baseWidgetName = "stories" + listingType + contentType + media;
    }
    else {
      if (topicSelectionIsASubject('content_topic'))
        baseWidgetName += "subjects/" + topic + listingType + contentType + media;
      else 
        baseWidgetName += "topics/" + topic + listingType + contentType + media;
    }
  }

  //alert("topic - " + topic + "; media - " + media + "; listingType - " + listingType + "; contentType - " + contentType + "; base widget name - " + baseWidgetName);

	return baseWidgetName;
}

function fetchJSWidgetParams(baseWidgetName)
{
	var widgetCode = '';
	var width      = getSelectedValue('js_width');
	var numStories = getSelectedValue('js_numStories');
	var ifrStyle   = (width == 'auto') ? 'padding:0;margin:0;overflow:auto;height:100%;width:100%'
                                     : 'padding:0;margin:0;overflow:auto;height:100%;width:' + width + 'px;';

		// Set up story count + widget width code
	if (numStories != defaultNumStories ) {
		widgetCode += '_NTW_numStories = ' + numStories + ';\n';
		if (width != 'auto')
			widgetCode += '_NTW_width = \'' + width + 'px\';\n';
	}
	else if (width != 'auto') {
		widgetCode += '_NTW_width = \'' + width + 'px\';\n';
	}

		// Set up code for hiding story elements
	var hideEltsCode = '';
	var hideEltsUrl = '';
  var defaultHideSettings = useDefaultFormatForMember() ? widgetTypeDefaults['topic'].uncheckedDefaults : widgetTypeDefaults[widgetType].uncheckedDefaults;
	var hideEltsArray = new Array();
	for (i = 0; i < storyElts.length; i++) {
		var elt = storyElts[i];
		var cb = getObj('show:' + elt);
		if (cb.style.display != 'hide') {
      if ((typeof defaultHideSettings[elt] != 'undefined') && defaultHideSettings[elt]) {
          // We have a default hide value -- so, if checked, we need to display the element
        if (cb.checked) {
          hideEltsCode += '_NTW_hideElts[\'' + elt + '\'] = false;\n';
          hideEltsUrl += '&' + elt + '=0';
          hideEltsArray[elt] = false;
        }
      }
      else {
          // No default hide value -- so, if unchecked, we need to hide the element
        if (!cb.checked) {
          hideEltsCode += '_NTW_hideElts[\'' + elt + '\'] = true;\n';
          hideEltsUrl += '&' + elt + '=1';
          hideEltsArray[elt] = true;
        }
      }
    }
	}

	if (hideEltsCode)
		widgetCode += '_NTW_hideElts = new Array();\n' + hideEltsCode;

	if (widgetCode)
		widgetCode = '<script type="text/javascript">\n' + widgetCode + '</script>\n';

		// Set up code for displaying the widget
	widgetCode += '<script src="' + baseUrl + baseWidgetName + '.json" type="text/javascript"></script>\n';
	widgetCode += '<script src="' + baseUrl + 'javascripts/widgets/formats/' + widgetFormat + '.json" type="text/javascript"></script>\n';
	widgetCode += '<script src="' + baseUrl + 'javascripts/render_widget.js" type="text/javascript"></script>';

		// Set up the url
	var widgetURL = baseUrl + 'widgets/preview?widgetName=' + baseWidgetName + '&widgetFormat=' + widgetFormat + '&numStories=' + numStories + '&width=' + width + hideEltsUrl;

		// Set up the params
	var jsWidgetParams = new Object();
	jsWidgetParams.width = width;
	jsWidgetParams.numStories = numStories;
	jsWidgetParams.hideElts = hideEltsArray;
	jsWidgetParams.widgetCode = widgetCode;
	jsWidgetParams.widgetURL = widgetURL;
	jsWidgetParams.iframeStyle = ifrStyle;

	return jsWidgetParams;
}

function showWidgetCode(code)
{
		// Do the right thing! Use the 'value' attribute of the textarea to set the code
		// If you want to set innerHTML, you have to escape all "<" and ">" first!
	getObj('widget_code').value = code;
}

function showPreview()
{
	var widgetCode = '';
	var iframeElt  = getObj('widget_preview');

  hideObj('member_placeholder');
  hideObj('source_placeholder');

	var baseWidgetName = getBaseWidgetName();
	if (!baseWidgetName) {
    showWidgetCode('');
    hide(iframeElt);
    if (widgetType == 'member')
      showObj('member_placeholder');
    else if (widgetType == 'source')
      showObj('source_placeholder');
		return;
  }

	var widgetURL;
	var jsWidgetParams = fetchJSWidgetParams(baseWidgetName);
	widgetURL = jsWidgetParams.widgetURL;
	widgetCode = jsWidgetParams.widgetCode;
	iframeEltStyle = jsWidgetParams.iframeStyle;

	showWidgetCode(widgetCode);

	hide(iframeElt);
	iframeElt.src = widgetURL;
	getObj('loading_msg').innerHTML = "Loading ."
	showObj('loading_msg');
	timer = setTimeout("updateMsg(1)", 200);

//	getObj('widget_code').select();
}

function refreshJSWidget()
{
	if (!jsPreviewWidget) {
		showPreview();
	}
	else {
		var baseWidgetName = getBaseWidgetName();
		if (!baseWidgetName)
			return;

		var params = fetchJSWidgetParams(baseWidgetName);

			// refresh it
		jsPreviewWidget.setHideElts(params.hideElts);
		jsPreviewWidget.setNumStories(params.numStories);
		jsPreviewWidget.setWidth(params.width);
		jsPreviewWidget.refresh();
			// update the iframe containing the widget 
		iframeEltStyle = params.iframeStyle;
		showIframe();
			// update widget code
		showWidgetCode(params.widgetCode);
	}
}

function updateMsg(numTries)
{
	var widgetDiv = getObj('loading_msg');
	if (numTries > 20) {
		widgetDiv.innerHTML = "Still loading ...";
		widgetDiv.style.margin.left = '100px';
	}
	else {
		widgetDiv.innerHTML += ".";
		numTries++;
		timer = setTimeout('updateMsg("' + numTries + '")', 200);
	}
}

function showIframe()
{
	hideObj('loading_msg');

     // overlay the iframe with the empty div so that the scrollbars and resizing can be hidden!
     // note that we have to display the widget, before it can be resized.  so, without the overlay technique,	
     // the scrollbars will flash on and off ... 
  showObj('temporary_overlay');
	showObj('widget_preview');
	var iframeElt = getObj('widget_preview');
  var wDoc = iframeElt.contentWindow || iframeElt.contentDocument;
	jsPreviewWidget = wDoc._ntw_widget;
  if (wDoc.document) {
    wDoc = wDoc.document;
  }
	  // Fetch the iframe document height!
	var h1 = 0, h2 = 0;
	if (wDoc.body.scrollHeight) { h1 = wDoc.body.scrollHeight; }
	if (wDoc.body.offsetHeight) { h2 = wDoc.body.offsetHeight; }
	var wHt = 20 + Math.max(h1, h2);
	iframeEltStyle += '; height:' + wHt + 'px;';

    // now that we have resized the iframe, hide the overlay!
  hideObj('temporary_overlay');
	setEltStyle(iframeElt, iframeEltStyle);
	clearTimeout(timer);
}

function selectCode()
{
	getObj('widget_code').select();
	getObj('widget_code').focus();
}
