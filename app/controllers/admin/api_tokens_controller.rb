class Admin::ApiTokensController < AdminController
  layout "public"

  def index
    @api_tokens = ApiToken.includes(:account, user: :boards).order(created_at: :desc)
    @accounts = Account.order(:name)
  end

  def new
    @api_token = ApiToken.new
    @accounts = Account.order(:name)
    @boards = Board.includes(:account).alphabetically
  end

  def create
    @api_token = ApiToken.new(api_token_params)
    @accounts = Account.order(:name)

    if @api_token.save
      redirect_to admin_api_tokens_path, notice: "Token created successfully. The token is: #{@api_token.token}"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @api_token = ApiToken.find(params[:id])
    @api_token.destroy
    redirect_to admin_api_tokens_path, notice: "Token deleted successfully"
  end

  def users_for_account
    account = Account.find(params[:account_id])
    # Include system_user for API tokens (system users are typically used for API tokens)
    users = account.users.includes(:identity).order(:name)
    
    render json: users.map { |user|
      {
        id: user.id,
        name: user.name,
        email: user.identity&.email_address || "No email",
        role: user.role
      }
    }
  end

  def boards_for_account
    account = Account.find(params[:account_id])
    boards = account.boards.alphabetically
    
    render json: boards.map { |board|
      {
        id: board.id,
        name: board.name,
        all_access: board.all_access
      }
    }
  end

  def board_info
    board = Board.find(params[:board_id])
    
    render json: {
      id: board.id,
      name: board.name,
      account_id: board.account.id,
      account_name: board.account.name
    }
  end

  private
    def api_token_params
      params.require(:api_token).permit(:account_id, :user_id, :name, :expires_at)
    end
end

