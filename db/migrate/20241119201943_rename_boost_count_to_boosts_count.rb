class RenameBoostCountToBoostsCount < ActiveRecord::Migration[8.0]
  def change
    rename_column :bubbles, :boost_count, :boosts_count
  end
end
