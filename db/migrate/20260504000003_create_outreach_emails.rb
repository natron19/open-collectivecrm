class CreateOutreachEmails < ActiveRecord::Migration[8.1]
  def change
    create_table :outreach_emails, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :lead, null: false, foreign_key: true, type: :uuid
      t.string :angle,            null: false
      t.string :subject
      t.text   :body
      t.text   :research_summary
      t.text   :sources
      t.text   :agent_trace
      t.text   :gemini_raw
      t.timestamps null: false
    end

    add_index :outreach_emails, [ :lead_id, :created_at ], name: "index_outreach_emails_on_lead_id_and_created_at"
  end
end
