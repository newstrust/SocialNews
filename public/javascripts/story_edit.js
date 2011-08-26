/**
* batch association setting (see excerpts/quotes in review.js)
*/
function remove_story_url(story_url) {
  $(story_url).parents('.story_url').hide().find("input[name='story[urls_attributes][][should_destroy]']").val(true);
}
