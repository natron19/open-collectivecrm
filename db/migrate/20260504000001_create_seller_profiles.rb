class CreateSellerProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :seller_profiles, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :product_name,        null: false
      t.text   :product_description, null: false
      t.timestamps null: false
    end

    add_index :seller_profiles, :user_id, unique: true, name: "index_seller_profiles_on_user_id_unique"
  end
end
