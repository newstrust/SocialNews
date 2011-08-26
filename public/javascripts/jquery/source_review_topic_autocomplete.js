/* Instantiate an autocomplete for the matching element */
jQuery.fn.source_review_topic_autocomplete = function(param_array_prefix, taxonomy, init_topics) {
  return this.each(function() {
		new $.SourceReviewTopicAutocomplete(this, param_array_prefix, taxonomy, init_topics);
	});
};

/*
 * Source Review Topic Autocomplete 'class'
 */
jQuery.SourceReviewTopicAutocomplete = function(div, param_array_prefix, taxonomy, init_topics) {
  var $selections        = $(div).find('div.expertise_list');
  var $input             = $(div).find('input#more_topics_autocomplete');
  var $hidden_inputs_div = $(div).find('div#hidden_form_inputs');
  var $selected_topics   = {};
  
  init();
  
  function input_name(key) {
    return param_array_prefix+"[]["+key+"]";
  }
  
  // lookup to see if this name is in our taxonomy
  function association_id_from_name(name) {
    var association_id = null;
    jQuery.each(taxonomy, function() {
      if (this.name.toLowerCase() == name.toLowerCase()) { // Case insensitive search
        association_id = this.id;
        return;
      }
    });
    return association_id;
  }
  
  // lookup to see if this name is in our taxonomy
  function association_name_from_id(id) {
    var name = null;
    jQuery.each(taxonomy, function() {
      if (this.id == id) {
        name = this.name;
        return;
      }
    });
    return name;
  }

  // DOM builder for new association entries. Create user-visible field PLUS hidden inputs.
  function add_selection(name, id) {
    if (!id) {
      // Dont bother if the name is not in our taxonomy
      id = association_id_from_name(name);
      if (!id) {
        return;
      }
    }

    // record it
    $selected_topics[name] = 1;

    // find the selection
    var selection = $selections.find("a#topic_" + id);
    if (selection.length < 1) {
      $selections.append(", ");
      selection = jQuery.create('a', {'href': '#', 'id': 'topic_' + id}, name);
      selection.click(function() { handle_topic_click($(this)); return false; });
      $selections.append(selection);
    }

    // add class, data, and click handler
    selection.addClass("selected");

    // form params are passed in as hidden inputs!
    // name must come FIRST so that Rails parses the form params correctly.
    var inputs_div = jQuery.create('div', {'id' : 'inputs_' + id}, '');
    var form_params = { name: name, id: id, should_destroy: false }
    jQuery.each(form_params, function(key, value) {
      inputs_div.append(hidden_field(input_name(key), value));
    });
    $hidden_inputs_div.append(inputs_div);
  }

  function remove_selection(name) {
    $selected_topics[name] = 0;
    selection.find("input[name='"+input_name('should_destroy')+"']").val(true);
  }

  function handle_topic_click(button)  {
      // get id & name
      var id   = button.attr('id').replace(/topic_/, '');
      var name = association_name_from_id(id);

      // Find the should_destroy_input input box.
      var should_destroy_input = $hidden_inputs_div.find("div#inputs_" + id + " input[name='" + input_name('should_destroy')+"']");

      // If we dont have it, then clearly this topic hasn't been selected yet.  Add it in!
      if (should_destroy_input.length < 1) {
        add_selection(name, id);
      }
      else if (button.hasClass('selected')) { // Unselect it
        $selected_topics[name] = 0;
        should_destroy_input.val(true);
        button.removeClass('selected');
      } 
      else { // Select it
        $selected_topics[name] = 1;
        should_destroy_input.val(false);
        button.addClass('selected');
      }
  }
  
  function init() {
    // so at least the green button appears to do something useful
    $(div).find('.add').click(function() {
      $input.focus();
    });

    // BUG: These links won't have topic data associated with them!
    // set up click handlers for all display topics
    $selections.find("a").click(function() { handle_topic_click($(this)); return false; });

    // set up inputs for initial topics
    for (var i = 0; i < init_topics.length; i++) {
      add_selection(init_topics[i], null);
    }

    // turn rich hashes into flat array
    var taxonomy_names = [];
    jQuery.each(taxonomy, function() {
      taxonomy_names.push(this.name);
    });

    // set up autocomplete with result callback
    $input.autocomplete(taxonomy_names, {matchContains: true, scroll: true, alwaysTriggerResult: true, dataType: 'json'})
      .result(function(event, data, formatted) {
        var name = typeof(data) == 'string' ? data : data[0];
        name = name.replace(/^\s+/, '').replace(/\s+$/, '').replace(/\s+/g, " ");
        if (!$selected_topics[name]) add_selection(name, null); // no duplicates!
        $(this).val("");
      });
  }
};

var hidden_field = function(name, value) {
  return jQuery.create('input', {type: 'hidden', name: name, value: value});
};
