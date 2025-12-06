class CardLink::CreateJob < ApplicationJob
  queue_as :default

  def perform(record, creator:)
    old_card_ids = record.card_links.pluck(:card_id)
    record.create_card_links(creator: creator)
    new_card_ids = record.card_links.pluck(:card_id)
    
    # Create events for newly linked cards
    newly_linked_card_ids = new_card_ids - old_card_ids
    return if newly_linked_card_ids.empty?
    
    card = record.card
    return unless card
    
    newly_linked_card_ids.each do |linked_card_id|
      linked_card = Card.find(linked_card_id)
      Event.create!(
        account: record.account,
        board: card.board,
        creator: creator,
        eventable: record,
        action: "card.linked",
        particulars: { linked_card_id: linked_card.number, linked_card_title: linked_card.title }
      )
    end
  end
end


