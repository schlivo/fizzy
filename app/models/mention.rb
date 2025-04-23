class Mention < ApplicationRecord
  include Notifiable

  belongs_to :source, polymorphic: true
  belongs_to :mentioner, class_name: "User"
  belongs_to :mentionee, class_name: "User", inverse_of: :mentions

  after_create_commit :add_mentionee_as_watcher

  def self_mention?
    mentioner == mentionee
  end

  private
    def add_mentionee_as_watcher
      source.watch_by(mentionee)
    end
end
