/**
* Mass Edit Form JS
*/

/**
* Story relations (= 'links')
* ajax call to backend to create story & update our view here.
*/
function init_story_relations(story_obj) {
  // set up story_lookup with custom handler
  $('.story_relation .story_lookup').story_lookup({}, function(data, div) {
    if (!data.error) {
      var $story_relation = $(div).parents('.story_relation');
      $story_relation.find(story_relation_input_selector(story_obj, 'related_story_id')).val(data.id);
      $story_relation.find(story_relation_input_selector(story_obj, 'title')).val(data.title);
    }
	});
};
function remove_story_relation(story_obj, story_relation) {
  if (confirm('Remove link?')) {
    $(story_relation).parents('.story_relation').hide().find(story_relation_input_selector(story_obj, 'should_destroy')).val(true);
  }
}
function story_relation_input_selector(story_obj, key) {
  var input_name = story_obj + "[story_relations_attributes][]["+key+"]";
  return "input[name='"+input_name+"']";
}

/**
* Generic Railsy helpers using jQuery.domec
*/
function link_to(text, url) {
  return jQuery.create('a', {href: url}, text);
};
