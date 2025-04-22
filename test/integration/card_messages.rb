require "test_helper"

class CardMessagesTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "messages system" do
    # Create a card
    post collection_cards_path(collections(:writebook))
    card = Card.last
    assert_equal 1, card.messages.count
    assert_predicate card.messages.last, :event_summary?
    assert_equal "created", card.messages.last.messageable.events.sole.action

    # Comment on it
    post collection_card_comments_path(collections(:writebook), card), params: { comment: { body: "Agreed." } }
    assert_equal 2, card.messages.count
    assert_predicate card.messages.last, :comment?
    assert_equal "Agreed.", card.messages.last.messageable.body

    # Assign it
    post collection_card_assignments_path(collections(:writebook), card), params: { assignee_id: users(:kevin).id }
    assert_equal 3, card.messages.count
    assert_predicate card.messages.last, :event_summary?
    assert_equal 1, card.messages.last.event_summary.events.count
    assert_equal "assigned", card.messages.last.messageable.events.last.action
  end
end
