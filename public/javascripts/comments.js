/*
 Comment Threading and Display Functionality 
*/
function enabled(element) {
  return ! $(element).hasClass('disabled_link');
}

function clearFormMode(form) {
  form.attr('mode', '');
}

function setFormMode(comment_id, comment_form_container, mode, callback) {
  var form = comment_form_container.find('form');
  form.attr('comment_id', comment_id);
  if (form.attr('mode') === mode && comment_form_container.css('display') !== 'none') {
    comment_form_container.hide("fast");
    form.attr('mode', '');
  } else {
    comment_form_container.show();
    form.attr('mode', mode);
    callback(comment_form_container, mode);
  }
}

function edit_comment_handler(event, button) {
  var id_parts = button.attr('id').split('_');
  var comment_id = id_parts[id_parts.length - 1];
  comment_form_container = $("#comment_form_container_" + comment_id);
  if (comment_form_container.length == 0) {
    comment_form_container = button.parents('.reviewComments').find(".reviewCommentFormContainer");
  }

  setFormMode(comment_id, comment_form_container, 'edit',
    function(cfc, m) {
      cfc.find("textarea").val($("#raw_comment_body_" + comment_id).text());
      cfc.find(".form_title").text("Edit Your Comment");
      var review_id = $(event.target).parents(".reviewComments").attr('review')
      if (review_id) {
        hideReviewCommentFooter(review_id);
        scrollIfNecessary(review_id);
      }
    });

  event.preventDefault();
}

function render_comment_thread(data) {
    $("#new_comment_form").show();
    $("#add_comments_header").show();

    $('*').unbind('click.forComments');
    if (data) {
        $("#comment_thread")[data.insert_mode](data.thread);
        $("#comment_thread_pagination").html(data.pagination);
        if (data.total_entries < 2) {
            $("#sort_oldest").addClass('disabled_link');
            $("#sort_newest").addClass('disabled_link');
        } else {
            $("#sort_oldest").removeClass('disabled_link');
            $("#sort_newest").removeClass('disabled_link');
        }
    }

    enableReplies();
    enablePermalinks();

    $('#add_comments_header').bind('click.forComments',
      function(event) {
        $('html,body').animate({ scrollTop: $("#add_comment").offset().top }, 'fast');
        event.preventDefault();
      });

    $(".hideable").bind('click.forComments',
      function(event) {
        ($(event.target).text() === 'Remove') ? hideComment($(event.target)) : unhideComment($(event.target));
        event.preventDefault();
      });

    
    $(".comment_link").bind('click.forComments',
      function(event) {
        var opts = NT.sort_options;
        opts.page = $(event.target).attr('page');
        getComments(NT.sort_options.last_sort, opts, 'append');
        event.preventDefault();
      });

    $(".comment_reply").bind('click.forComments',
      function(event) {
        var id_parts = $(this).attr('id').split('_');
        var comment_id = id_parts[id_parts.length - 1];
        setFormMode(comment_id, $("#comment_form_container_" + comment_id), 'reply',
          function(cfc, m) {
            cfc.find("textarea").val("");
            cfc.find(".form_title").text("Add A Reply");
          });
        event.preventDefault();
      });

    $(".comment_edit").bind('click.forComments', function(event) { edit_comment_handler(event, $(this)) });

    $("#comment_create").bind('click.forComments',
      function(event) {
        var form = $(event.target).parent().get(0);
        while (form.tagName !== 'FORM') {
            form = $(form).parent().get(0);
        }
        var str = $(form).serialize();
        if ($(form).find('#comment_body').attr('value').match(/^\s*$/)) {
          alert('Please enter the body of the comment');
          event.preventDefault();
          return;
        }

        $('.creating_comment').show();
        blockAjax($(event.target),
        function() {
            $.ajax({
                dataType: 'json',
                data: str,
                type: "POST",
                url: '/discussions/comments.json',
                success: function(data) {
                    if (data.error) {
                      alert(data.error);
                    }
                    else {
                      $('.comment_body').val('');
                      if (data.total_comments && data.total_comments > 0) {
                          $('.comment_count').text("(" + data.total_comments + ")");
                      }
                      $('#created_comments').append(data.html);
                      render_comment_thread();
                      $('#comment_' + data.comment.id).addClass('new_comment');
                    }
                },
                error: function(XMLHttpRequest, textStatus, errorThrown) {},
                complete: function() {
                    $('.creating_comment').hide();
                    unblockAjax($(event.target));
                }
            });
        });
        event.preventDefault();
    });

    $('.showReplies').bind('click.forComments',
    function(event) {
        var next,
        child,
        method,
        comment_thread,
        local_show_hide;
        if (/Show/i.test($(event.target).text())) {
            method = 'show';
            $(event.target).text($(event.target).text().replace(/Show/i, 'Hide'));
        } else {
            method = 'hide';
            $(event.target).text($(event.target).text().replace(/Hide/i, 'Show'));
        }
        comment_thread = $("#comment_" + $(event.target).attr('comment_id') + '_thread');
        $(comment_thread).children('.comment_container').each(function(index, element) {
            child = $($(element).children('.comment')[0]);
            child[method]();
        });
        $(comment_thread)[method]();
        event.preventDefault();
    });

    // Top level comments will also open or close all subthreads too.
    $('.depth_0 .showReplies').bind('click.forComments',
    function(event) {
        if (/Show/i.test($(event.target).text())) {
            method = 'show';
        } else {
            method = 'hide';
        }
        $("#comment_" + $(event.target).attr('comment_id') + "_thread .showReplies").each(function(index, element) {
            if (/Show/i.test($(element).text()) && method !== 'show') {
                $(element).click();
            }
            if (/Hide/i.test($(element).text()) && method !== 'hide') {
                $(element).click();
            }
        });
        event.preventDefault();
    });
    removeDuplicateComments();
    add_textile_support_links();
    assignFlags(NT.comment_options.flag_url, '.forComments');
    addReplyLinks(NT.comment_options.reply_url);
}

function getComments(order, options, mode) {
    var insert_mode = (mode === undefined || mode === 'html') ? 'html': 'append';
    $('.retrieving_comments').show();
    if (!options) {
        options = NT.sort_options;
    }
    var params = {
        filter_by: order,
        klass: NT.comment_options.klass,
        id: NT.comment_options.id,
        page: options.page || 1,
        per_page: options.per_page || NT.sort_options.per_page
    };

    if (insert_mode === 'append') {
        $('.retrieving_paginated_comments').show();
    }

    var path = "";
    $.ajax({
        dataType: 'json',
        type: "POST",
        data: params,
        url: NT.comment_options.sort_url,
        success: function(data) {
            $('.retrieving_comments').hide();
            $('.retrieving_paginated_comments').hide();
            data.insert_mode = insert_mode;
            render_comment_thread(data);

            if (data.total_comments && data.total_comments > 0) {
                $('.comment_count').text("(" + data.total_comments + ")");
            }

            // Hide all but the top level comment for the loaded page unless
            // the user has toggled all the comments visible.
            if (/Show/i.test($('.toggle_all_replies').text())) {
                $('.showReplies').each(function(index, element) {
                    $(element).text($(element).text().replace(/Hide/i, 'Show'));
                });
                for (x = 1; x < 25; x++) {
                    $("#comment_page_" + data.current_page + " .depth_" + x + ".comment").hide();
                }
            }
        }
    });
}

function addReplyLinks(url) {
    $('.reply_submit').bind('click.forComments',
    function(event) {
        submitCommentForm(event, url);
    });
}

// Submit the comment reply or edit form using AJAX instead of making a HTTP post.
function submitCommentForm(event, url) {
    var form = $(event.target).parent().get(0);
    while (form.tagName !== 'FORM') {
        form = $(form).parent().get(0);
    }

    // SSS: What is going on here??  Why are we walking up the comment container chain?
    var comment_container = $(form).parent().get(0);
    while ($(comment_container).hasClass("comment_container") !== true) {
        comment_container = $(comment_container).parent().get(0);
    }
    var comment_id = $(comment_container).attr('comment_id');
    var str = $(form).serialize();
    var form_mode = $(form).attr('mode');
    if (form_mode === 'edit') {
        url = '/discussions/comments/' + comment_id + '.json';
        str += "&_method=put";
    }
    $("#submitting_" + comment_id).show();
    blockAjax($(event.target),
    function() {
        $.ajax({
            dataType: 'json',
            data: str,
            type: "POST",
            url: url,
            success: function(data) {
                if (form_mode === 'reply') {
                    $("#comment_" + comment_id + "_thread").remove();
                    $(comment_container).replaceWith(data.html);
                    render_comment_thread();
                    updateReplyCountsForComment(comment_id);
                    $('html,body').animate({ scrollTop: $("#comment_target_" + data.comment.id).offset().top }, 'fast');
                }
                $("#comment_form_container_" + comment_id).hide("fast");
                updateComment(data.comment);

                if (data.total_comments && data.total_comments > 0) {
                    $('.comment_count').text("(" + data.total_comments + ")");
                }
            },
            error: function(XMLHttpRequest, textStatus, errorThrown) { },
            complete: function() {
                $("#submitting_" + comment_id).hide();
                unblockAjax($(event.target));
            }
        });
    });
    event.preventDefault();
}

function getPermalink(permalink) {
    var comment = $("#comment_" + permalink);
    var commentableType = $(comment).attr('commentable_type');
    switch (commentableType) {
    case 'Review':
        getReviewPermalink(permalink);
        getComments('oldest', NT.sort_options); // We still need to show the other comments, which are not linked to reviews.
        $('.retrieving_comments').show();
        break;
    default:
        getRemotePermalink(permalink);
        break;
    }
}

function getRemotePermalink(permalink) {
    $('.retrieving_permalink').show();
    $('html,body').animate({ scrollTop: $('.retrieving_permalink').offset().top });

    $("#comment_thread").html('');
    $.ajax({
        dataType: 'json',
        type: "GET",
        data: {
            _method: 'get'
        },
        url: '/discussions/comments/' + permalink + '.json',
        success: function(data) {
            $('.retrieving_comments').hide();
            $('.retrieving_paginated_comments').hide();
            data.insert_mode = 'html';
            render_comment_thread(data);
            $("#comment_" + data.comment.id + ".comment").addClass('selectedComment');
            $('html,body').animate({ scrollTop: $("#comment_target_" + data.comment.id).offset().top }, 'fast');
            $('.threadMenu').hide();
            $('.permalinkMenu').show();
        },
        complete: function(data) {
            $('.retrieving_permalink').hide();
        }
    });
}

function buildSorter() {
    $('#sort_newest').bind('click',
    function(event) {
        if (enabled(event.target)) {
            NT.sort_options.page = 1;
            NT.sort_options.last_sort = 'newest';
            getComments(NT.sort_options.last_sort, NT.sort_options);
            $(event.target).addClass('selected');
            $('#sort_oldest').removeClass('selected');
        }
        event.preventDefault();
    });

    $('#sort_oldest').bind('click',
    function(event) {
        if (enabled(event.target)) {
            NT.sort_options.page = 1;
            NT.sort_options.last_sort = 'oldest';
            getComments(NT.sort_options.last_sort, NT.sort_options);
            $(event.target).addClass('selected');
            $('#sort_newest').removeClass('selected');
        }
        event.preventDefault();
    });
}

function enableReplies() {
    if ($(".depth_1").length === 0) {
        $(".toggle_all_replies").addClass('disabled_link');
        $(".toggle_all_replies").bind('click',
        function(event) {
            event.preventDefault();
        });
    } else {
        toggleAllReplies();
        $(".toggle_all_replies").removeClass('disabled_link');
        $('.showReplies').each(function(index, element) {
            if ($(element).attr('reply_count') > 0) {
                $(element).show();
            } else {
                $(element).hide();
            }
        });
    }
}

function enablePermalinks() {
  $('*').unbind('click.forPermalinks');
  $(".permalink a").each(function(index, element) {
      url = window.location.href;
      if (url.indexOf("#") >= 0) {
          url = url.split("#")[0];
      }
      $(element).attr('href', url + "#p-" + $(element).attr('comment_id'));
  });

  $(".permalink a").bind('click.forPermalinks',
  function(event) {
      url = window.location.href;
      if (url.indexOf("#p") >= 0) {
          url = url.split("#p")[0];
      }
      window.location.href = url + "#p-" + $(event.target).attr('comment_id');
      getPermalink($(event.target).attr('comment_id'));
      event.preventDefault();
  });
}

function hideComment(element) {
    var id = $(element).attr('comment_id');
    var str = {
        _method: 'delete'
    };
    blockAjax(element,
    function() {
        $(element).pulse(true);
        $.ajax({
            dataType: 'json',
            data: str,
            type: "POST",
            url: '/discussions/comments/' + id + '.json',
            success: function(data) {
                $(element).text('Restore');
                $("#hidden_comment_" + id).show();
                $("#server_result_" + id).html(data.flash.notice);
            },
            complete: function(data) {
                unblockAjax(element);
                $(element).pulse(false);
            }
        });
    });
}

function unhideComment(element) {
    var id = $(element).attr('comment_id');
    blockAjax(element,
    function() {
        $(element).pulse(true);
        $.ajax({
            dataType: 'json',
            type: "POST",
            data: {
                _method: 'post'
            },
            url: '/discussions/comments/' + id + '/undestroy.json',
            success: function(data) {
                $(element).text('Remove');
                $("#hidden_comment_" + id).hide();
                $("#server_result_" + id).html(data.flash.notice);
            },
            complete: function(data) {
                unblockAjax(element);
                $(element).pulse(false);
            }
        });
    });
}

function toggleAllReplies() {
    $(".toggle_all_replies").bind('click.forComments',
    function(event) {
        if ($(event.target).text() === 'Show All Replies') {
            $(event.target).text('Hide All Replies');
            $('.showReplies').each(function(index, element) {
                $(element).text($(element).text().replace(/Hide/i, 'Show'));
                $(element).click();
            });
        } else {
            $(event.target).text('Show All Replies');
            $('.showReplies').each(function(index, element) {
                $(element).text($(element).text().replace(/Show/i, 'Hide'));
                $(element).click();
            });
        }
        event.preventDefault();
    });
}

function updateReplyCountsForComment(comment_id) {
    var ancestor_ids = $('#comment_container_' + comment_id).attr('ancestor_ids').split('-');
    $(ancestor_ids).each(function(index, id) {
        val = $('#reply_count_' + id).text();
        if (val !== '') {
            val = $('#reply_count_' + id).text().replace(/\(/, '').replace(/\)/, '');
            val = parseInt(val, 10) + 1;
        }
        $('#reply_count_' + id).text("(" + val + ")");
    });
}

function updateComment(comment) {
    if (comment.parent) {
        if (comment.parent.replies_count > 0) {
            $("#reply_count_" + comment.parent.id).text(" ( " + comment.parent.replies_count + ")");
        } else {
            $("#reply_count_" + comment.parent.id).text("");
        }
    }

    $('#comment_content_' + comment.id).html(comment.body);
    $('#raw_comment_body_' + comment.id).html(comment.body_source);

    if (comment.likes_count === 0) {
        $("#likable_members_" + comment.id).hide();
        $("#likable_members_after_" + comment.id).hide();
        $("#likable_members_gallery_" + comment.id).hide();
    } else {
        if (comment.likes_count === 1) {
            str = comment.likes_count + " person";
            str2 = " likes this comment.";
        } else {
            str = comment.likes_count + " people";
            str2 = " like this comment.";
        }
        $("#likable_members_gallery_" + comment.id).hide();
        $("#likable_members_" + comment.id).text(str);
        $("#likable_members_after_" + comment.id).text(str2);
        $("#likable_members_after_" + comment.id).show();
        $("#likable_members_" + comment.id).show();
    }

    if (comment.likes_count > 0) {
        $("#likes_count_" + comment.id).text(" (" + comment.likes_count + ")");
    } else {
        $("#likes_count_" + comment.id).text("");
    }

    // This may not always succeed because flags are just shown to admins.
    try {
        if (comment.flags_count > 0) {
            $("#flags_count_" + comment.id).text(" (" + comment.flags_count + ")");
        } else {
            $("#flags_count_" + comment.id).text("");
        }
    } catch(e) {}
}

// Comments created by the member are added to the bottom of the comment form. However,
// when a user paginates the records it is possible to see the same comment twice. In this case
// we need to remove the member's comment from the list of comments that appaer at the bottom of the
// interface, and keep the one that appears in the thread.
function removeDuplicateComments() {
    var visible_comments = [];
    $('#comment_thread .comment_container').each(function(index, element) {
        visible_comments.push($(element).attr('comment_id'));
    });
    $(visible_comments).each(function(index, id) {
        $("#created_comments #comment_container_" + id).remove();
    });
}

/*
 Comments used in Reviews
*/
function getReviewPermalink(permalink) {
    enablePermalinks();
    var reviewComment = $('#comment_' + permalink);
    if (reviewComment) {
        highlightComment(permalink);
        var review_id = $(reviewComment).attr('review');
        var commentsToggle = $('a.toggleReviewComments[review=' + review_id + ']'); 
        if (commentsToggle){
            showReviewComments(commentsToggle);
/**            
 * SSS: Hmm .. This should normally work, but for some reason this function getReviewPermalink() is being called twice!
 * Both times form getPermalink -- but I dont know where the first call is coming from.  The second call (which should have been
 * the only one) is coming from app/views/shared/_review_comments_js.html.erb
 * Effectively, the 2nd call is negating the special case code below! Sigh!
 *
            // SSS: FIXME: This is because rather than hiding all comments, we always show the first comment -- special case.
            // In such a situation, if there is only 1 comment, the toggle is in the opposite state (open) than if it has more than 1 (closed).
            // To get the desired effect for the permalink, click it once more to handle this special case.
            if (getCommentsCount(review_id) == 1) {
              commentsToggle.click();
            }
**/
            conditionallyShowReviewCommentFooter(review_id);
        }
    }
}

function scrollIfNecessary(review_id) {
  var winHeight      = $(window).height() - 50; // 50 pixels is an arbitrary buffer to give us some room for error (I am just picking 50 as an arbitrary number)
  var winScroll_y    = $(window).scrollTop();
  var commentHdr_y   = $('div[review=' + review_id + '] .reviewCommentHeader').offset().top;
  var commentsHeight = $('div[review=' + review_id + '] .reviewCommentsContainer').height()
  var formHeight     = $('div[review=' + review_id + '] .reviewCommentFormContainer').height()
  var diff           = ((commentHdr_y - winScroll_y) + commentsHeight + formHeight) - winHeight;
  if (diff > 0) {
    $('html,body').animate({ scrollTop: winScroll_y + diff }, 'fast');
  }
}

function addReviewComment(event) {
    event.preventDefault();
    var review_id = $(event.target).attr('review');
    var formContainer = $('div[review=' + review_id + '] .reviewCommentFormContainer');
    formContainer.show();

    // Reset form mode, title, text area so that if we are switching between edit & add, the text area is always empty + we are in new comment mode
    clearFormMode(formContainer.find("form"));
    formContainer.find("textarea").val("");
    $('div[review=' + review_id + '] .form_title').text("");

    // Hide footer
    hideReviewCommentFooter(review_id);

    // Scroll
    scrollIfNecessary(review_id);
}

function commentsAreHidden(review_id) {
  var review_obj = $('span[review='+review_id+']');
  var commentsToggle = $('a.toggleReviewComments[review=' + review_id + ']'); 
  return (/Show/i.test(commentsToggle.text())) ? true : false;
}

function toggleReviewComments(event) {
    event.preventDefault();
    var tgt = $(event.target);
    var review_id  = tgt.attr('review');
    var review_obj = $('span[review='+review_id+']');
    if (commentsAreHidden(review_id)) {
        method = 'show';
        review_obj.removeClass('show_comments');
        review_obj.addClass('hide_comments');
        tgt.text(tgt.text().replace(/Show/i, 'Hide'));
        conditionallyShowReviewCommentFooter(review_id);
    } else {
        method = 'hide';
        review_obj.removeClass('hide_comments');
        review_obj.addClass('show_comments');
        hideReviewCommentFooter(review_id);
        tgt.text(tgt.text().replace(/Hide/i, 'Show'));
    }
    $('.reviewComments[review=' + review_id + '] .comment')[method]();
}

function showReviewComments(element){
  $('*').unbind('click.toggleReviewComments');
  $('.toggleReviewComments').bind('click.toggleReviewComments', toggleReviewComments);
  if (/Show/i.test($(element).text())) {
    $(element).click();
  }
  conditionallyShowReviewCommentFooter(review_id);
}

function hideReviewComments(element){
  $('*').unbind('click.toggleReviewComments');
  $('.toggleReviewComments').bind('click.toggleReviewComments', toggleReviewComments);
  if (/Hide/i.test($(element).text())) {
    $(element).click();
  }
}

function getCommentsCount(review_id) {
  return parseInt($('.reviewCommentsContainer[review=' + review_id + ']').attr('comments_count'), 10);
}

function hideReviewCommentFooter(review_id) {
  $('.reviewCommentFooter[review=' + review_id + ']').hide();
}

function conditionallyShowReviewCommentFooter(review_id) {
    var comments_count = getCommentsCount(review_id);
    if (comments_count > 0) { // Show the footer if there is at least 1 comment
        $('.reviewCommentFooter[review=' + review_id + ']').show();
    }
}

function bindRenderedReviewComments(review_id) {
    $('div[review=' + review_id + '] .addReviewComment').bind('click.forReviewComments', addReviewComment);
    $('div[review=' + review_id + '] .toggleReviewComments').bind('click.forReviewComments', toggleReviewComments);
}

// Update comment display after a new comment has been added
function updateReviewComments(review_id, data) {
    $('div[review=' + review_id + '] .reviewCommentFormContainer').hide('fast');
//    $('div[review=' + review_id + '] .reviewCommentFormContainer textarea').val("");

    // New comment 
    if (data.html) {
      // SSS: FIXME: Note: This is effectively resetting the entire html thread!
      // But, why are we getting the whole darned comment thread back?
      $('div[review=' + review_id + '] .reviewCommentsContainer').html(data.html);

      // Reenable handlers!
      // 1. Enable add & toggle handlers
      // 2. Make all (not just the new one) comments editable
      bindRenderedReviewComments(review_id);
      $(".comment_edit").bind('click.forComments', function(event) { edit_comment_handler(event, $(this)) });

      // Since the comment threads comes in hidden state, toggle the state of the comment container to reveal the whole thread
      // If this is the first comment, toggle it again because the comment thread is returned in 'open' state by default 
      // and our first toggle would have closed it.
      $('div[review=' + review_id + '] .toggleReviewComments').click();
      var numComments = getCommentsCount(review_id);
      if (numComments == 0)
        $('div[review=' + review_id + '] .toggleReviewComments').click();

      // Scroll to the bottom
      //$('html,body').animate({ scrollTop: $("#comment_" + data.comment.id).offset().top }, 'fast');
      scrollIfNecessary(review_id);

      // Update attribute count tracking # of comments
      $('.reviewCommentsContainer[review=' + review_id + ']').attr('comments_count', numComments+1);
    }
    else {// edit of old comment -- update existing data
      updateComment(data.comment);
    }

    // highlight the comment and show the footer
    highlightComment(data.comment.id);
    conditionallyShowReviewCommentFooter(review_id);
}

function highlightComment(id) {
  $('.new_comment').each(function(index, element){
    $(element).removeClass('new_comment');
  });
  $("#comment_" + id).addClass('new_comment');
}

function cancelReviewCommentForm(event, review_id) {
  $('div[review=' + review_id + '] .reviewCommentFormContainer').hide('fast');

/*
 * We are now doing this when adding a new comment rather than when we cancel the edit
  $('div[review=' + review_id + '] .reviewCommentFormContainer textarea').val("");
  $('div[review=' + review_id + '] .form_title').text("");
*/
  if (commentsAreHidden(review_id))
    hideReviewCommentFooter(review_id);
  else
    conditionallyShowReviewCommentFooter(review_id);

  event.preventDefault();
}

// Submit the comment add or edit form using AJAX instead of making a HTTP post.
function submitReviewCommentForm(event, review_id) {
    var form = $(event.target).parent().get(0);
    while (form.tagName !== 'FORM') {
        form = $(form).parent().get(0);
    }

    // catch empty comments
    if ($(form).find('#comment_body').attr('value').match(/^\s*$/)) {
      alert('Please enter the body of the comment');
      event.preventDefault();
      return;
    }

    var str = $(form).serialize();
    var form_mode = $(form).attr('mode');
    if (form_mode === 'edit') {
        var comment_id = $(form).attr('comment_id');
        url = '/discussions/comments/' + comment_id + '.json';
        str += "&_method=put";
    }
    else {
        url = NT.comment_options.create_url;
    }

    $(".creating_comment").show();
    blockAjax($(event.target),
    function() {
        $.ajax({
            dataType: 'json',
            data: str,
            type: "POST",
            url: url,
            success: function(data) {
                if (data.error) {
                  alert(data.error);
                }
                else {
                  updateReviewComments(review_id, data);
                  // Reset form
                  var cfc = $('div[review=' + review_id + '] .reviewCommentFormContainer');
                  cfc.find("textarea").val("");
                  cfc.find(".form_title").text("");
                }
            },
            error: function(XMLHttpRequest, textStatus, errorThrown) { },
            complete: function() {
                $(".creating_comment").hide();
                unblockAjax($(event.target));
            }
        });
    });
    event.preventDefault();
}
