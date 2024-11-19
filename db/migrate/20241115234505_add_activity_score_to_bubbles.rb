class AddActivityScoreToBubbles < ActiveRecord::Migration[8.0]
  def change
    add_column :bubbles, :activity_score, :integer, null: false, default: 0
  end
end
