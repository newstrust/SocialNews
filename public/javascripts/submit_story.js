/** ----------------------- Buttons: submit story code ----------------------- */

/* Courtesy: http://stackoverflow.com/questions/984510/what-is-my-script-src-url */
var scriptSource = (function(scripts) { 
  var scripts = document.getElementsByTagName('script');
  var script  = scripts[scripts.length - 1]; 
  return (script.getAttribute.length !== undefined) ?
           //FF/Chrome/Safari 
           script.src : //(only FYI, this would work also in IE8)
           //IE 6/7/8
           script.getAttribute('src', 4); //using 4 (and not -1) see MSDN http://msdn.microsoft.com/en-us/library/ms536429(VS.85).aspx
}());

socialnews_base_url = scriptSource.replace(/(https?:\/\/[^\/]*)\/.*/, '$1') + "/";

if (typeof socialnews_base_url === 'undefined') socialnews_base_url = 'http://socialnews.com/';

/**
* first val of array is eval'd with socialnews_ prefix to get user-entered values
* second part is querystring key for rails.
* Note: source_ownership has been removed as we don't really have a place for it.
*/
var params_map = {
  "story_url": "story[url]", "story_title": "story[title]",
  "story_type": "story[story_type]", "story_date": "story[story_date]", "story_authors": "story[journalist_names]",
  "story_quote": "story[excerpt]", "publication_name": "story[authorships_attributes][][name]",
  "referred_by": "story[referred_by]",
  "story_subject": "story[taggings_attributes][][name]", "story_topic": "story[taggings_attributes][][name]",
  "story_subject_2": "story[taggings_attributes][][name]", "story_topic_2": "story[taggings_attributes][][name]",
  "story_subject_3": "story[taggings_attributes][][name]", "story_topic_3": "story[taggings_attributes][][name]",
  "story_subject_4": "story[taggings_attributes][][name]", "story_topic_4": "story[taggings_attributes][][name]",
  "story_subject_5": "story[taggings_attributes][][name]", "story_topic_5": "story[taggings_attributes][][name]"};

var story_types_map = {
  "News Report": "news_report", "Special Report": "special_report", "News Analysis": "news_analysis",
  "Opinion": "opinion", "Editorial": "editorial", "Interview": "interview",
  "Poll": "poll", "Review": "review", "Blog Post": "opinion", "Podcast": "opinion",
  "Comment": "comment", "Advocacy": "advocacy", "Speech": "speech",
  "Statement": "statement", "Press Release": "press_release", "Advertisement": "advertisement",
  "Entertainment": "entertainment", "Comedy News": "comedy_news", "Editorial Cartoons": "cartoon",
  "Other": "other", "Not Applicable": "other", "Not sure": "not_sure"};

function undefine_submit_params() {
	for (var param in params_map) eval('socialnews_'+param+' = undefined');
	
	socialnews_icon = undefined;
	socialnews_unlisted_publication_name = undefined; // this one isn't passed in, so not in params array.
}

function encode_for_url(value) {
	return encodeURIComponent(value).replace(/'/g, "\\'");
}

function build_submit_url() {
	var base_url = socialnews_base_url + 'submit';
	var query_string = "";
	
	// set up defaults
  if (typeof socialnews_story_url == 'undefined') socialnews_story_url = document.URL;
	if (typeof socialnews_story_title == 'undefined') socialnews_story_title = document.title;
	if (typeof socialnews_publication_name != 'undefined' && socialnews_publication_name.match(/other/i)) {
	  socialnews_publication_name = (typeof socialnews_unlisted_publication_name != 'undefined') ?
	    socialnews_unlisted_publication_name:
	    null;
	}
	if (typeof socialnews_story_type == 'string') socialnews_story_type = story_types_map[socialnews_story_type];
	
	// build query string
	for (var param in params_map) {
	  var val = null;
	  eval("if (typeof socialnews_"+param+" != 'undefined') val = socialnews_"+param);
	  if (val) {
	    query_string += '&' + params_map[param] + '=' + encode_for_url(val);
	  }
	}
	
	return base_url + query_string.replace(/&/, '?');
}

function get_script_element() {
	if (typeof nt_button_count == 'undefined')
		nt_button_count = 1;
	else
		nt_button_count = 2;

	var count   = 0;
  var scripts = document.getElementsByTagName('script');
	var scriptUrl = socialnews_base_url + 'js/submit_story.js';
  scriptUrl = scriptUrl.replace(/preview./, '').replace(/beta./, '').replace(/www./, '');
	for (var i = 0; i < scripts.length; i++) {
    var srcUrl = scripts[i].src.replace(/preview./, '').replace(/beta./, '').replace(/www./, '');
		if (srcUrl == scriptUrl) {
			count++;
			if (count == nt_button_count) {
				return scripts[i];
			}
			else {
					// Get rid of the duplicate scripts
				scripts[i].parentNode.removeChild(scripts[i]);
			}
		}
	}

	return undefined;
}

function socialnews_embed_button() {
		// Ensure that we have an icon!
	if ((typeof socialnews_icon != 'string') || !socialnews_icon)
		socialnews_icon = socialnews_base_url + 'images/socialnews.gif';

		// Create the button element
	var ntButton = document.createElement('span');

		// Build the story url right here using the values of the params available at the point where this script is executing.
		// This lets us embed the same button multiple times on the page using the same script variables, and without requiring
		// the user to define distinct variables at different places.
		//
		// If we don't build the url right here and now using the values that are available at this site, 'socialnews_submit_story()'
		// will be executed at a point where all button sites are visible and only the last setting is visible.
	var storyUrl = build_submit_url();
	ntButton.innerHTML = '<img style="border:none; cursor:pointer" onClick="socialnews_submit_story(\'' + storyUrl + '\')" src="' + socialnews_icon + '" alt="Review it on SocialNews" title="Review it on SocialNews">';
	ntButton.id        = "socialnews_submit_story_button";

		// Insert the button just before the script element in the DOM
	var ntScriptElt = get_script_element();
	ntScriptElt.parentNode.insertBefore(ntButton, ntScriptElt);

		// undefine all the js variables so that they don't pollute other settings of other nt buttons on the same page
	undefine_submit_params();
}

function socialnews_submit_story(submitUrl) {
		// Open a window with the URL -- but open the popup version
	var w = window.open(submitUrl + "&popup=true", 'SocialNews'+(new Date()).getMilliseconds(), 'dependent=no,scrollbars=yes,resizable=yes,alwaysRaised=yes,status=yes,directories=yes,location=yes,menubar=yes,toolbar=yes,width=400,height=600,modal=no');

		// Shift focus to the window
	w.focus();
}

	// Embed the button into the page!
socialnews_embed_button();
