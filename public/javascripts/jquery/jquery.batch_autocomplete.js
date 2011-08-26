/**
* batch_autocomplete plugin
*
* Let user select multiple association values using the jQuery.autocomplete plugin.
* Values not within our existing taxonomy will be added to it.
* All cruddy create/update/delete functionality takes place on the JS side.
*/


/**
* Just instantiate an autocomplete for each matching div
*/
jQuery.fn.batch_autocomplete = function(param_array_prefix, taxonomy, current_associations, association_params, callback) {
  return this.each(function() {
		new $.BatchAutocomplete(this, param_array_prefix, taxonomy, current_associations, association_params, callback);
	});
};


/**
* BatchAutocomplete 'class'
*/
jQuery.BatchAutocomplete = function(div, param_array_prefix, taxonomy, current_associations, association_params, callback) {
  var $selections = $(div).find('ul.selections');
  var $input = $(div).find('input');
  
  // so that story_autopopulate plugin can fill these fields in
  $(div).bind("set_selections", function(event, associations) {
    $selections.empty();
    if (associations !==  undefined) {
      jQuery.each(associations, function() { add_selection(this.name, this.id); });
    }
    return $(this);
  });
  
  init();
  
  // so at least the green button appears to do something useful
  $(div).find('.add').click(function() {
    $input.focus();
  });
  
  // lookup to see if this name is in our taxonomy... this would be one line of code in ruby...!
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
  
  function remove_selection(selection) {
    var do_remove = true;
    if ($selections.find('li').length == 1) {
      do_remove = (confirm("Remove last one?"));
    }
    if (do_remove) { // mark for deletion in batch_association & hide
      selection.hide().find("input[name='"+input_name('should_destroy')+"']").val(true);
    }
    invoke_callback();
  }
  
  // DOM builder for new association entries. Create user-visible field PLUS hidden inputs.
  function add_selection(name, id) {
    var selection = jQuery.create('li', null, name);
    
    selection.mouseover(function() {
      $(this).toggleClass('del');
    }).mouseout(function() {
      $(this).toggleClass('del');
    }).click(function() {
      remove_selection($(this));
    });
    
    // form params as hidden inputs!
    var form_params = {};
    form_params.name = name; // name must come FIRST so that Rails parses the form params correctly.
    if (id !== undefined) form_params.id = id; // append ID if we have one for existing records
    form_params.should_destroy = false;
    jQuery.extend(form_params, association_params); // pass back anything that was passed in
    jQuery.each(form_params, function(key, value) {
      selection.append(hidden_field(input_name(key), value));
    });
    
    // if assoc obj is in taxonomy, give it a CSS class
    if (association_id_from_name(name)) selection.addClass('in_taxonomy');
    
    $selections.append(selection);
    
    invoke_callback();
  }
  
  function has_selection(name) {
    var has_selection = false;
    $selections.find("li:visible input[name='"+input_name('name')+"']").each(function() {
      has_selection |= ($(this).val().toLowerCase() == name.toLowerCase());
    });
    return has_selection;
  }
  
  function input_name(key) {
    return param_array_prefix+"[]["+key+"]";
  }
  
  function init() {
    // populate selections
    jQuery.each(current_associations, function() {
      add_selection(this.name, this.id);
    });

    // turn rich hashes into flat array
    var taxonomy_names = [];
    jQuery.each(taxonomy, function() {
      taxonomy_names.push(this.name);
    });

    // set up autcomplete with result callback
    $input.autocomplete(taxonomy_names, {matchContains: true, scroll: true, alwaysTriggerResult: true, dataType: 'json'})
      .result(function(event, data, formatted) {
        var name = typeof(data) == 'string' ? data : data[0];
        name = name.replace(/^\s+/, '').replace(/\s+$/, '').replace(/\s+/g, " ");
        if (!has_selection(name)) add_selection(name);
        $(this).val("");
      });
  }
  
  /**
  * namely for Toolbar, which needs limit_form_height called here.
  */
  function invoke_callback() {
    if (callback) eval(callback+"()");
  }
};


/**
* Generic Railsy helpers using jQuery.domec
* these should go in application.js or something...
*/
var link_to_function = function(text, linked_function) {
  return jQuery.create('a', {href: "#"}, text).click(function() {
    linked_function();
    return false;
  });
};
var hidden_field = function(name, value) {
  return jQuery.create('input', {type: 'hidden', name: name, value: value});
};
