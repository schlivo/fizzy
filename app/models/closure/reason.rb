class Closure::Reason < ApplicationRecord
  DEFAULT_LABELS = [
    "Done",
    "Duplicate",
    "Maybe later",
    "Working as intended",
    "Not now"
  ]

  FALLBACK_LABEL = "Done"

  class << self
    def labels
      pluck(:label).presence || [ FALLBACK_LABEL ]
    end

    def default
      labels.first
    end

    def create_defaults
      DEFAULT_LABELS.each do |label|
        create! label: label
      end
    end
  end
end
