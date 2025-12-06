module CardLinks
  extend ActiveSupport::Concern

  included do
    has_many :card_links, as: :source, dependent: :destroy
    has_many :linked_cards, through: :card_links, source: :card
    after_save_commit :create_card_links_later, if: :should_create_card_links?
  end

  def create_card_links(creator: Current.user)
    scan_card_links.each do |card|
      card_links.find_or_create_by!(card: card, creator: creator)
    end
  end

  private
    def scan_card_links
      card_numbers = extract_card_numbers
      return [] if card_numbers.empty?

      Current.account.cards.where(number: card_numbers).to_a
    end

    def extract_card_numbers
      numbers = []
      rich_text_associations.each do |association|
        rich_text = send(association.name)
        next unless rich_text&.body

        # Extract from plain text (handles #123, #card-123)
        plain_text = rich_text.to_plain_text
        numbers.concat(extract_from_plain_text(plain_text))

        # Extract from HTML (handles markdown links, HTML links with data-card-id)
        html = rich_text.body.to_s
        numbers.concat(extract_from_html(html))
      end

      numbers.uniq
    end

    def extract_from_plain_text(text)
      numbers = []

      # Match #123 or #card-123 patterns
      text.scan(/#(?:card-)?(\d+)/i) do |match|
        numbers << match[0].to_i
      end

      numbers
    end

    def extract_from_html(html)
      numbers = []
      return numbers if html.blank?

      doc = Nokogiri::HTML::DocumentFragment.parse(html)

      # Extract from links with data-card-id attribute
      doc.css("a[data-card-id]").each do |link|
        card_id = link["data-card-id"]
        if card_id =~ /^\d+$/
          numbers << card_id.to_i
        end
      end

      # Extract from markdown-style links: [text](#123) or [text](card:123)
      doc.css("a[href]").each do |link|
        href = link["href"]
        if href
          # Match #123 or card:123 patterns in href
          if match = href.match(/#(\d+)$/)
            numbers << match[1].to_i
          elsif match = href.match(/^card:(\d+)$/)
            numbers << match[1].to_i
          end
        end
      end

      # Extract from plain text in HTML (handles #123 in text nodes)
      doc.traverse do |node|
        if node.text?
          text = node.text
          text.scan(/#(?:card-)?(\d+)/i) do |match|
            numbers << match[0].to_i
          end
        end
      end

      numbers
    end

    def rich_text_associations
      self.class.reflect_on_all_associations(:has_one).filter { it.klass == ActionText::RichText }
    end

    def should_create_card_links?
      linkable? && (linkable_content_changed? || should_check_card_links?)
    end

    def linkable_content_changed?
      rich_text_associations.any? { send(it.name)&.body_previously_changed? }
    end

    def create_card_links_later
      CardLink::CreateJob.perform_later(self, creator: Current.user)
    end

    # Template method
    def linkable?
      true
    end

    def should_check_card_links?
      false
    end
end

