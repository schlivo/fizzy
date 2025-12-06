class Api::NotificationsController < Api::BaseController
  def index
    notifications = Current.user.notifications
    
    # Filter by unread_only if provided
    if params[:unread_only] == "true" || params[:unread_only] == true
      notifications = notifications.unread
    end
    
    # Pagination
    limit = [ (params[:limit] || 50).to_i, 100 ].min
    offset = params[:offset].to_i
    
    total = notifications.count
    unread_count = Current.user.notifications.unread.count
    
    notifications = notifications.ordered.preloaded.limit(limit).offset(offset)
    
    render json: {
      notifications: notifications.map { |notification| notification_json(notification) },
      total: total,
      unread_count: unread_count
    }
  end

  def read
    notification = Current.user.notifications.find(params[:id])
    notification.read
    
    render json: {
      id: notification.id,
      read: notification.read?,
      read_at: notification.read_at&.iso8601
    }
  end

  def mark_all_read
    count = Current.user.notifications.unread.count
    Current.user.notifications.unread.find_each(&:read)
    
    render json: {
      marked_count: count
    }
  end

  private
    def notification_json(notification)
      card = notification.card
      board = card&.board
      actor = notification.creator
      
      # Determine notification type
      type = if notification.source_type == "Mention"
        "user.mentioned"
      elsif notification.source_type == "Event"
        case notification.source&.action
        when "comment_created"
          "comment.created"
        when "card_assigned"
          "card.assigned"
        when "card_published"
          "card.published"
        when "card_closed"
          "card.closed"
        when "card_reopened"
          "card.reopened"
        else
          "card.updated"
        end
      else
        "notification"
      end
      
      result = {
        id: notification.id,
        type: type,
        read: notification.read?,
        occurred_at: notification.created_at.iso8601,
        actor: {
          id: actor.id,
          name: actor.name,
          email: actor.identity&.email_address
        }
      }
      
      if card
        result[:card] = {
          id: card.number,
          title: card.title
        }
      end
      
      if board
        result[:board] = {
          id: board.id,
          name: board.name
        }
      end
      
      # Include comment with mentions if it's a comment-related notification
      if notification.source_type == "Event" && notification.source&.eventable_type == "Comment"
        comment = notification.source.eventable
        result[:comment] = {
          id: comment.id,
          body: comment.body&.to_plain_text,
          body_plain_text: comment.body&.to_plain_text,
          mentions: comment.mentions.includes(:mentionee).map do |mention|
            mentionee = mention.mentionee
            {
              user_id: mentionee.id,
              username: mentionee.identity&.email_address&.split("@")&.first || mentionee.name.downcase.gsub(/\s+/, "."),
              name: mentionee.name,
              email: mentionee.identity&.email_address
            }
          end
        }
      elsif notification.source_type == "Mention"
        mention = notification.source
        comment = mention.source if mention.source.is_a?(Comment)
        if comment
          result[:comment] = {
            id: comment.id,
            body: comment.body&.to_plain_text,
            body_plain_text: comment.body&.to_plain_text,
            mentions: comment.mentions.includes(:mentionee).map do |m|
              mentionee = m.mentionee
              {
                user_id: mentionee.id,
                username: mentionee.identity&.email_address&.split("@")&.first || mentionee.name.downcase.gsub(/\s+/, "."),
                name: mentionee.name,
                email: mentionee.identity&.email_address
              }
            end
          }
        end
      end
      
      result
    end
end

