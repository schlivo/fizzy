require "test_helper"

class FilterTest < ActiveSupport::TestCase
  test "persistence" do
    assert_difference "users(:david).filters.count", +1 do
      filter = users(:david).filters.persist!(indexed_by: "most_boosted")

      assert_changes "filter.reload.updated_at" do
        assert_equal filter, users(:david).filters.persist!(indexed_by: "most_boosted")
      end
    end
  end

  test "bubbles" do
    Current.set session: sessions(:david) do
      @new_bucket = accounts("37s").buckets.create! name: "Inaccessible Bucket"
      @new_bubble = @new_bucket.bubbles.create!
    end

    assert_not_includes users(:kevin).filters.new.bubbles, @new_bubble

    filter = users(:david).filters.new indexed_by: "most_discussed", assignee_ids: [ users(:jz).id ], tag_ids: [ tags(:mobile).id ]
    assert_equal [ bubbles(:layout) ], filter.bubbles

    filter = users(:david).filters.new assignments: "unassigned", bucket_ids: [ @new_bucket.id ]
    assert_equal [ @new_bubble ], filter.bubbles

    filter = users(:david).filters.new indexed_by: "popped"
    assert_equal [ bubbles(:shipping) ], filter.bubbles
  end

  test "turning into params" do
    expected = { indexed_by: "most_discussed", tag_ids: [ tags(:mobile).id ], assignee_ids: [ users(:jz).id ], filter_id: filters(:jz_assignments).id }
    assert_equal expected.stringify_keys, filters(:jz_assignments).to_params.to_h
  end

  test "param sanitization" do
    filter = users(:david).filters.new indexed_by: "most_active", tag_ids: "", assignee_ids: [ users(:jz).id ], bucket_ids: [ buckets(:writebook).id ]
    expected = { assignee_ids: [ users(:jz).id ], bucket_ids: [ buckets(:writebook).id ] }
    assert_equal expected.stringify_keys, filter.params
  end

  test "cacheable" do
    assert_not filters(:jz_assignments).cacheable?
    assert users(:david).filters.create!(bucket_ids: [ buckets(:writebook).id ]).cacheable?
  end

  test "resource removal" do
    filter = users(:david).filters.create! tag_ids: [ tags(:mobile).id ], bucket_ids: [ buckets(:writebook).id ]

    assert_includes filter.params["tag_ids"], tags(:mobile).id
    assert_includes filter.tags, tags(:mobile)
    assert_includes filter.params["bucket_ids"], buckets(:writebook).id
    assert_includes filter.buckets, buckets(:writebook)

    assert_changes "filter.reload.updated_at" do
      tags(:mobile).destroy!
    end
    assert_nil filter.reload.params["tag_ids"]

    assert_changes "Filter.exists?(filter.id)" do
      buckets(:writebook).destroy!
    end
  end

  test "summary" do
    assert_equal "<mark>Most discussed</mark>, tagged <mark>#Mobile</mark>, and assigned to <mark>JZ</mark> in <mark>all projects</mark>", filters(:jz_assignments).summary
  end

  test "plain summary" do
    assert_equal "Most discussed, tagged #Mobile, and assigned to JZ in all projects", filters(:jz_assignments).plain_summary
  end
end
