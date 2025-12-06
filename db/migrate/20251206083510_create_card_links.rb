class CreateCardLinks < ActiveRecord::Migration[8.2]
  def change
    create_table :card_links, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :source_id, null: false
      t.string :source_type, null: false
      t.uuid :card_id, null: false
      t.uuid :creator_id, null: false
      t.timestamps

      t.index :account_id
      t.index [ :source_type, :source_id ], name: "index_card_links_on_source"
      t.index :card_id
      t.index :creator_id
      t.index [ :source_type, :source_id, :card_id ], name: "index_card_links_on_source_and_card", unique: true
    end
  end
end
