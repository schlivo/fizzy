class Access < ApplicationRecord
  belongs_to :collection
  belongs_to :user

  enum :involvement, %i[ access_only watching everything ].index_by(&:itself)

  scope :ordered_by_recently_accessed, -> { order(accessed_at: :desc) }

  after_destroy_commit :clean_inaccessible_data_later

  def accessed
    touch :accessed_at unless recently_accessed?
  end

  private
    def recently_accessed?
      accessed_at&.> 5.minutes.ago
    end

    def clean_inaccessible_data_later
      Collection::CleanInaccessibleDataJob.perform_later(user, collection)
    end
end
