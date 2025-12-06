class CreateCardLinks < ActiveRecord::Migration[8.2]
  def change
    create_table :card_links, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.uuid :source_id, null: false
      t.string :source_type, null: false
      t.references :card, null: false, foreign_key: true, type: :uuid
      t.references :creator, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.timestamps

      t.index [ :source_type, :source_id ], name: "index_card_links_on_source"
      t.index [ :source_type, :source_id, :card_id ], name: "index_card_links_on_source_and_card", unique: true
    end
  end
end
