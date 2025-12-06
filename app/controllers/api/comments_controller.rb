class Api::CommentsController < Api::BaseController
  before_action :set_card

  def index
    comments = @card.comments.chronologically.preloaded
      .includes(mentions: :mentionee, card_links: :card, creator: :identity)
    render json: comments.map { |comment| comment_json(comment) }
  end

  def create
    comment = @card.comments.create!(
      creator: Current.user,
      body: params[:body]
    )

    # Reload with associations to avoid N+1 queries
    comment = Comment.preloaded
      .includes(mentions: :mentionee, card_links: :card, creator: :identity)
      .find(comment.id)

    render json: comment_json(comment), status: :created
  end

  private
    def set_card
      @card = Current.account.cards.find_by!(number: params[:card_id])
    end

    def comment_json(comment)
      {
        id: comment.id,
        body: comment.body&.to_plain_text,
        body_plain_text: comment.body&.to_plain_text,
        card_id: comment.card.number,
        creator: {
          id: comment.creator.id,
          name: comment.creator.name
        },
        mentions: comment.mentions.map do |mention|
          mentionee = mention.mentionee
          {
            user_id: mentionee.id,
            username: mentionee.identity&.email_address&.split("@")&.first || mentionee.name.downcase.gsub(/\s+/, "."),
            name: mentionee.name,
            email: mentionee.identity&.email_address
          }
        end,
        card_links: comment.card_links.map do |card_link|
          {
            card_id: card_link.card.number,
            title: card_link.card.title
          }
        end,
        created_at: comment.created_at.iso8601
      }
    end
end
