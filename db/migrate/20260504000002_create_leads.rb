class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :first_name,   null: false
      t.string :last_name,    null: false
      t.string :company,      null: false
      t.string :company_size, null: false
      t.string :role
      t.string :email
      t.string :website
      t.string :stage,        null: false, default: "prospect"
      t.text   :notes
      t.timestamps null: false
    end

    add_index :leads, [ :user_id, :stage ], name: "index_leads_on_user_id_and_stage"
    add_index :leads, :created_at,          name: "index_leads_on_created_at"
  end
end
