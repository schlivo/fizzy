require "test_helper"

class BoostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_difference "bubbles(:logo).reload.boosts_count", +1 do
      post bucket_bubble_boosts_url(buckets(:writebook), bubbles(:logo), format: :turbo_stream)
    end

    assert_turbo_stream action: :update, target: dom_id(bubbles(:logo), :boosts)
  end
end
