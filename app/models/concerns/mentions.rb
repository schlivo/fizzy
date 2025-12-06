module Mentions
  extend ActiveSupport::Concern

  included do
    has_many :mentions, as: :source, dependent: :destroy
    has_many :mentionees, through: :mentions
    after_save_commit :create_mentions_later, if: :should_create_mentions?
  end

  def create_mentions(mentioner: Current.user)
    scan_mentionees.each do |mentionee|
      mentionee.mentioned_by mentioner, at: self
    end
  end

  def mentionable_content
    rich_text_associations.collect { send(it.name)&.to_plain_text }.compact.join(" ")
  end

  private
    def scan_mentionees
      (mentionees_from_attachments + mentionees_from_plain_text) & mentionable_users
    end

    def mentionees_from_attachments
      rich_text_associations.flat_map { send(it.name)&.body&.attachments&.collect { it.attachable } }.compact
    end

    def mentionees_from_plain_text
      return [] unless mentionable_content.present?

      mentions = []
      plain_text = mentionable_content

      # Match @username or @username@domain patterns
      plain_text.scan(/@([\w.]+(?:@[\w.-]+)?)/) do |match|
        mention_handle = match[0]
        users = find_users_by_mention(mention_handle)
        mentions.concat(users)
      end

      mentions.uniq
    end

    def find_users_by_mention(mention_handle)
      # Handle format: username@domain or just username
      if mention_handle.include?("@")
        # Full email format: username@domain
        email = mention_handle
        identity = Identity.find_by(email_address: email)
        return [] unless identity

        users = identity.users.where(account: account)
        return users.to_a if users.any?
      else
        # Username only: try to match by email prefix or name
        username = mention_handle.downcase
        mentionable_users.select do |user|
          email_prefix = user.identity&.email_address&.split("@")&.first&.downcase
          name_downcase = user.name.downcase.gsub(/\s+/, ".")
          
          email_prefix == username || name_downcase == username || 
            user.name.downcase.include?(username) || 
            (email_prefix && email_prefix.include?(username))
        end
      end
    end

    def mentionable_users
      board.users
    end

    def rich_text_associations
      self.class.reflect_on_all_associations(:has_one).filter { it.klass == ActionText::RichText }
    end

    def should_create_mentions?
      mentionable? && (mentionable_content_changed? || should_check_mentions?)
    end

    def mentionable_content_changed?
      rich_text_associations.any? { send(it.name)&.body_previously_changed? }
    end

    def create_mentions_later
      Mention::CreateJob.perform_later(self, mentioner: Current.user)
    end

    # Template method
    def mentionable?
      true
    end

    def should_check_mentions?
      false
    end
end
