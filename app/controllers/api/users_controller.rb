class Api::UsersController < Api::BaseController
  def find
    raise ArgumentError, "email parameter is required" unless params[:email].present?
    
    email = params[:email]
    identity = Identity.find_by(email_address: email)
    raise ActiveRecord::RecordNotFound, "User not found" unless identity
    
    user = identity.users.find_by(account: Current.account)
    raise ActiveRecord::RecordNotFound, "User not found" unless user
    
    render json: {
      id: user.id,
      name: user.name,
      email: email
    }
  end

  def search
    raise ArgumentError, "q parameter is required" unless params[:q].present?
    
    query = params[:q].strip
    limit = [ (params[:limit] || 10).to_i, 50 ].min
    
    users = Current.account.users.active
    
    # Filter by board if provided
    if params[:board_id].present?
      board = Current.account.boards.find(params[:board_id])
      users = users.joins(:accesses).where(accesses: { board: board }).or(
        users.where(id: board.creator_id)
      ).distinct
    end
    
    # Search by name, email, or ID
    if query =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
      # UUID search
      users = users.where(id: query)
    else
      # Text search
      users = users.joins(:identity).where(
        "users.name LIKE ? OR identities.email_address LIKE ?",
        "%#{query}%", "%#{query}%"
      )
    end
    
    users = users.limit(limit)
    
    render json: {
      users: users.map { |user|
        {
          id: user.id,
          name: user.name,
          email: user.identity&.email_address,
          avatar_url: user.avatar.attached? ? url_for(user.avatar) : nil
        }
      }
    }
  end
end


