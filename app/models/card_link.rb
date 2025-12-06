class CardLink < ApplicationRecord
  belongs_to :account, default: -> { source.account }
  belongs_to :source, polymorphic: true
  belongs_to :card
  belongs_to :creator, class_name: "User"

  delegate :board, to: :source

  validates :card_id, uniqueness: { scope: [ :source_type, :source_id ] }
end

