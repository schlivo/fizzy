class HashFilterParams < ActiveRecord::Migration[8.0]
  def change
    change_column_default :filters, :params, from: {}, to: nil
    change_column :filters, :params, :string, null: false
    rename_column :filters, :params, :params_digest
  end
end
