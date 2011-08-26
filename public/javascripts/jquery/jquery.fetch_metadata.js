/**
* Fetch Story Metadata
*
* This is for the "Edit" tab in the toolbar, to populate story with info queried from various APIs,
* using CSS highlight classes to indicate to user what needs their attention.
* This is kicked off on page load for members with sufficient privileges.
*/

jQuery.fn.fetch_metadata = function() {
  return this.each(function() {
		new $.FetchMetadata(this);
	});
};

jQuery.FetchMetadata = function(form) {
  var $form = $(form);
  var $form_display = $form.find('.longform_window, .button_footer');
  var $messages = $('#fetch_metadata_messages p');
  
  if (member_is_logged_in && lookup_on_ready) fetch_metadata();
  
  /**
  * Kick off metadata fetch
  */
  function fetch_metadata() {
    // update UI
    $messages.hide().filter('#fetch_metadata_loading').show();
    $form_display.hide();
    limit_form_height();

    submit_with_onsubmit($('form#fetch_metadata'));
  };
  
  /**
  * Get story_data JSON hash back from server, populate fields for user!
  */
  $form.bind("populate_edit_form", function(event, data, error) {
    // set URL field if it got changed (?)
    if (!error) $form.find('input[name=url]').val(data.url);
    
    // TODO: wipe out commented-out cruft when we're sure it's not needed
    // if (!disable_lookup) {
      // reset_all_fields(false); // no need to do this in toolbar
      if (!data.error) set_all_fields(data);
    // }
    
    $messages.hide().filter('#fetch_metadata_done').show();
    $form_display.slideDown(150, limit_form_height);
    
    /**
    * Go through story data hash from server, trigger populate_and_highlight for each field
    */
    function set_all_fields(story_info, reset) {
      // give the one nested object defaults
      if (!story_info.date_components) story_info.date_components = {month: '', day: '', year: ''};

      populate_and_highlight(story_info.title, 'textarea#story_title', populate_val, reset);
      populate_and_highlight(story_info.story_type, 'select#story_story_type', populate_val, reset);
        // Since we toggle the guess field in the populate_and_highlight function, we need to pass in an additional
        // param for day and year so that they use the same state (!field_has_guess) as the month value
      date_has_guess = populate_and_highlight(story_info.date_components.month, 'select#story_date_components_month', populate_val, reset);
      populate_and_highlight(story_info.date_components.day, 'select#story_date_components_day', populate_val, reset, !date_has_guess);
      populate_and_highlight(story_info.date_components.year, 'select#story_date_components_year', populate_val, reset, !date_has_guess);
      populate_and_highlight(story_info.authors, 'input#story_journalist_names', populate_val, reset);
      populate_and_highlight(story_info.quote, 'textarea#story_excerpt', populate_val, reset);
      populate_and_highlight(story_info.authorships, 'div#story_authorships_attributes_', populate_batch_autocomplete, reset);
      populate_and_highlight(story_info.topics, 'div#story_taggings_attributes_', populate_batch_autocomplete, reset);
    };
    
    /**
    * No longer used; this was for the old case when user would paste an entirely different URL in.
    */
    function reset_all_fields(reset) {
      set_all_fields({}, reset);
    };
    
    /**
    * Use correct populate handler and highlight field...
    * Some of this tricky boolean logic is out-dated, was for special overwrite cases.
    */
    function populate_and_highlight(datum, field_query, handler, reset, shared_field) {
      var $field = $form.find(field_query);
      var $field_holster = $field.parents('div.form_field');
      var field_has_guess = $field_holster.hasClass('guess');
      if ((reset && (field_has_guess || shared_field)) || (datum && (!field_has_guess || shared_field))) {
        $field.each(function(){
          handler($(this), datum);
        });
        // SSS: March 11 2010.  No longer displaying yellow highlights!
        // $field_holster.toggleClassAbsolute('guess', !reset);
      }
      return field_has_guess;
    };
    
    /**
    * Standard form field populate handler
    */
    function populate_val(field, datum) {
      if (!datum) datum = ""
      return $(field).val(datum);
    };
    
    /**
    * Custom batch_autocomplete field populate handler
    */
    function populate_batch_autocomplete(field, datum) {
        // Wrapping the data in an array, because the datum array is being expanded into multiple arguments to the js call,
        // rather than being passing in as a single array argument
      return $(field).trigger("set_selections", [datum]);
    };
    
    return $(this);
  });
}
