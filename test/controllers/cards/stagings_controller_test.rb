require "test_helper"

class Cards::StagingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    put card_staging_path(cards(:logo)), params: { stage_id: workflow_stages(:qa_in_progress).id }, as: :turbo_stream
    assert_card_container_rerendered(cards(:logo))
  end
end
