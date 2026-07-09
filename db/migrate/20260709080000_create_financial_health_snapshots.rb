class CreateFinancialHealthSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :financial_health_snapshots, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.date :date, null: false
      t.integer :total, null: false
      t.string :rank
      t.jsonb :pillars, null: false, default: []

      t.timestamps
    end

    add_index :financial_health_snapshots, [ :user_id, :date ], unique: true
  end
end
