require "test_helper"

class Api::CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts("37s")
    @user = users(:david)
    @board = boards(:writebook)
    
    # Create API token for authentication
    @api_token = ApiToken.create!(
      account: @account,
      user: @user,
      name: "Test API Token"
    )
    
    Current.account = @account
    Current.user = @user
  end

  teardown do
    Current.clear_all
  end

  test "index requires authentication" do
    get "/api/cards"
    assert_response :unauthorized
  end

  test "index returns cards with valid token" do
    get "/api/cards", headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any?
    
    # Check structure of first card
    card = json.first
    assert_includes card.keys, "id"
    assert_includes card.keys, "title"
    assert_includes card.keys, "description"
    assert_includes card.keys, "status"
    assert_includes card.keys, "column"
    assert_includes card.keys, "board_id"
    assert_includes card.keys, "tags"
    assert_includes card.keys, "assignees"
    assert_includes card.keys, "created_at"
    assert_includes card.keys, "updated_at"
  end

  test "index filters by board_id" do
    other_board = boards(:private)
    
    get "/api/cards", 
        params: { board_id: @board.id },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    json.each do |card|
      assert_equal @board.id, card["board_id"]
    end
  end

  test "index filters by creator_ids" do
    kevin = users(:kevin)
    
    get "/api/cards",
        params: { creator_ids: [@user.id] },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    json.each do |card|
      # Cards should be created by the specified user
      card_record = Card.find_by(number: card["id"])
      assert_equal @user.id, card_record.creator_id
    end
  end

  test "index filters by assignee_ids" do
    kevin = users(:kevin)
    card = cards(:logo)
    Current.user = @user
    # Assign if not already assigned
    card.toggle_assignment(kevin) unless card.assigned_to?(kevin)
    
    get "/api/cards",
        params: { assignee_ids: [kevin.id] },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    # Check that at least one card is assigned to kevin
    assigned_cards = json.select do |c|
      card_record = Card.find_by(number: c["id"])
      card_record&.assignees&.include?(kevin)
    end
    assert assigned_cards.any?, "Expected at least one card assigned to kevin"
  end

  test "index filters by column name" do
    column = @board.columns.first
    return skip "No columns in board" unless column
    
    get "/api/cards",
        params: { column: column.name },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    json.each do |card|
      card_record = Card.find_by(number: card["id"])
      assert_equal column.id, card_record.column_id if card_record.column
    end
  end

  test "index filters by virtual column NOT NOW" do
    card = cards(:logo)
    card.postpone(user: @user)
    
    get "/api/cards",
        params: { column: "NOT NOW" },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert json.any?
    json.each do |c|
      card_record = Card.find_by(number: c["id"])
      assert card_record.postponed?
      assert_equal "NOT NOW", c["column"]
    end
  end

  test "index filters by virtual column MAYBE?" do
    card = cards(:logo)
    card.send_back_to_triage(skip_event: false)
    
    get "/api/cards",
        params: { column: "MAYBE?" },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    json.each do |c|
      card_record = Card.find_by(number: c["id"])
      assert card_record.awaiting_triage?
      assert_equal "MAYBE?", c["column"]
    end
  end

  test "index filters by virtual column DONE" do
    card = cards(:logo)
    card.close(user: @user)
    
    get "/api/cards",
        params: { column: "DONE" },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    json.each do |c|
      card_record = Card.find_by(number: c["id"])
      assert card_record.closed?
      assert_equal "DONE", c["column"]
    end
  end

  test "index filters by tags" do
    card = cards(:logo)
    tag = @account.tags.find_or_create_by!(title: "urgent")
    card.tags << tag unless card.tags.include?(tag)
    
    get "/api/cards",
        params: { tags: ["urgent"] },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert json.any?
    json.each do |c|
      card_record = Card.find_by(number: c["id"])
      assert card_record.tags.pluck(:title).include?("urgent")
    end
  end

  test "index filters by created_at time window" do
    # Create a card today
    today_card = @board.cards.create!(
      creator: @user,
      title: "Today's card",
      status: "published",
      created_at: Time.current
    )
    
    get "/api/cards",
        params: { created_at: "today" },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    json.each do |c|
      card_record = Card.find_by(number: c["id"])
      assert card_record.created_at >= Time.current.beginning_of_day
      assert card_record.created_at <= Time.current.end_of_day
    end
  end

  test "index filters by status closed" do
    card = cards(:logo)
    card.close(user: @user)
    
    get "/api/cards",
        params: { status: "closed" },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    json.each do |c|
      card_record = Card.find_by(number: c["id"])
      assert card_record.closed?
    end
  end

  test "index filters by status not_now" do
    card = cards(:logo)
    card.postpone(user: @user)
    
    get "/api/cards",
        params: { status: "not_now" },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    json.each do |c|
      card_record = Card.find_by(number: c["id"])
      assert card_record.postponed?
    end
  end

  test "index sorts by newest" do
    get "/api/cards",
        params: { sort: "newest" },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    return if json.length < 2
    
    timestamps = json.map { |c| Time.parse(c["created_at"]) }
    assert timestamps.each_cons(2).all? { |a, b| a >= b }
  end

  test "index sorts by oldest" do
    get "/api/cards",
        params: { sort: "oldest" },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    return if json.length < 2
    
    timestamps = json.map { |c| Time.parse(c["created_at"]) }
    assert timestamps.each_cons(2).all? { |a, b| a <= b }
  end

  test "index combines multiple filters" do
    kevin = users(:kevin)
    card = cards(:logo)
    Current.user = @user
    # Assign if not already assigned
    card.toggle_assignment(kevin) unless card.assigned_to?(kevin)
    tag = @account.tags.find_or_create_by!(title: "test")
    card.tags << tag unless card.tags.include?(tag)
    
    get "/api/cards",
        params: { 
          assignee_ids: [kevin.id],
          tags: ["test"],
          board_id: @board.id
        },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    json.each do |c|
      card_record = Card.find_by(number: c["id"])
      assert card_record.assignees.include?(kevin), "Card #{c['id']} should be assigned to kevin"
      assert card_record.tags.pluck(:title).include?("test"), "Card #{c['id']} should have test tag"
      assert_equal @board.id, card_record.board_id, "Card #{c['id']} should be in the board"
    end
  end

  test "index returns empty array when no assignees found" do
    get "/api/cards",
        params: { assignee_ids: ["nonexistent-uuid"] },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal [], json
  end

  test "index returns empty array when no tags found" do
    get "/api/cards",
        params: { tags: ["nonexistent-tag"] },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal [], json
  end

  test "index raises error for invalid column" do
    get "/api/cards",
        params: { column: "Nonexistent Column" },
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :not_found
    
    json = JSON.parse(response.body)
    assert_equal "not_found", json["error"]
  end

  test "tags returns card tags" do
    card = cards(:logo)
    tag1 = @account.tags.find_or_create_by!(title: "urgent")
    tag2 = @account.tags.find_or_create_by!(title: "bug")
    card.tags << tag1 unless card.tags.include?(tag1)
    card.tags << tag2 unless card.tags.include?(tag2)
    
    get "/api/cards/#{card.number}/tags",
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_includes json.keys, "tags"
    assert json["tags"].is_a?(Array)
    assert_includes json["tags"], "urgent"
    assert_includes json["tags"], "bug"
  end

  test "tags returns empty array for card with no tags" do
    card = cards(:logo)
    card.tags.clear
    
    get "/api/cards/#{card.number}/tags",
        headers: { "Authorization" => "Bearer #{@api_token.token}" }
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_includes json.keys, "tags"
    assert_equal [], json["tags"]
  end

  test "tags requires authentication" do
    card = cards(:logo)
    get "/api/cards/#{card.number}/tags"
    assert_response :unauthorized
  end
end

