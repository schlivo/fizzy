module Bubble::Boostable
  extend ActiveSupport::Concern

  included do
    scope :ordered_by_boosts, -> { order boosts_count: :desc }
  end

  def boost!
    transaction do
      track_event :boosted
      increment! :boosts_count
      rescore
    end
  end
end
