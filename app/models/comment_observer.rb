class CommentObserver < ActiveRecord::Observer
  def after_create(comment)
    if comment.initial_ancestor_id
      @parent = Comment.find(comment.initial_ancestor_id)
      comment.nest_inside(@parent.id)
      comment.reload
    end

    # NOTE: Because of the way that the callback chain works with the BetterNestedSet plugin
    # if you put methods here like for example sending mail, you will potentially break the 
    # nesting feature of the comments. I've moved all notifications to the CommentsController#create method.
  end
end
