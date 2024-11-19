require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "searchable by body" do
    message = bubbles(:logo).capture Comment.new(body: "I'd prefer something more rustic")

    assert_includes Comment.search("something rustic"), message.comment
  end

  test "updating bubble counter" do
    assert_difference %w[ bubbles(:logo).comments_count bubbles(:logo).activity_score ], +1 do
      bubbles(:logo).capture Comment.new(body: "I'd prefer something more rustic")
    end

    assert_difference %w[ bubbles(:logo).comments_count bubbles(:logo).activity_score ], -1 do
      bubbles(:logo).messages.comments.last.destroy
    end
  end
end
