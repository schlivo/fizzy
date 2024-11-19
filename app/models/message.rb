class Message < ApplicationRecord
  belongs_to :bubble, touch: true

  delegated_type :messageable, types: Messageable::TYPES, inverse_of: :message, dependent: :destroy

  scope :chronologically, -> { order created_at: :asc, id: :desc }

  after_create :created
  after_destroy :destroyed

  private
    def created
      bubble.comment_created if comment?
    end

    def destroyed
      bubble.comment_destroyed if comment?
    end
end
