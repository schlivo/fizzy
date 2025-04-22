require "test_helper"

class Card::StagedTest < ActiveSupport::TestCase
  setup { Current.session = sessions(:david) }

  test "change stage" do
    assert_difference -> { Event.where(action: :staged).count }, +1 do
      cards(:logo).change_stage_to(workflow_stages(:qa_in_progress))
      assert_equal workflow_stages(:qa_in_progress), cards(:logo).reload.stage
    end
  end
end
