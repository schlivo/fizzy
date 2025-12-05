class Api::BoardsController < Api::BaseController
  def index
    boards = Current.user.boards.alphabetically

    render json: boards.map { |board| board_json(board) }
  end

  def show
    board = Current.user.boards.find(params[:id])

    render json: board_json(board)
  end

  private
    def board_json(board)
      {
        id: board.id,
        name: board.name,
        all_access: board.all_access,
        created_at: board.created_at.iso8601,
        updated_at: board.updated_at.iso8601,
        creator: {
          id: board.creator.id,
          name: board.creator.name
        },
        columns: board.columns.sorted.map { |column|
          {
            id: column.id,
            name: column.name,
            color: column.color.to_s
          }
        },
        virtual_columns: [
          {
            name: "NOT NOW",
            description: "Virtual column for postponed cards. Cards in this state are temporarily set aside.",
            is_virtual: true
          },
          {
            name: "MAYBE?",
            description: "Virtual column for cards awaiting triage (not yet assigned to a column).",
            is_virtual: true
          },
          {
            name: "DONE",
            description: "Virtual column for closed cards. Use the /close endpoint or set column to 'DONE'.",
            is_virtual: true
          }
        ]
      }
    end
end

