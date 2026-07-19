class CreateUserDays < ActiveRecord::Migration[7.2]
  def up
    create_table :user_days, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :date, null: false
      t.datetime :created_at, null: false, default: -> { "NOW()" }
    end
    add_index :user_days, [ :user_id, :date ], unique: true

    # Seed history from login sessions so the funnel isn't blind before
    # today. Sessions only capture logins (not every active day), but it's
    # an honest lower bound for the backfill window.
    execute <<~SQL
      INSERT INTO user_days (id, user_id, date, created_at)
      SELECT gen_random_uuid(), s.user_id, s.created_at::date, NOW()
      FROM sessions s
      GROUP BY s.user_id, s.created_at::date
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    drop_table :user_days
  end
end
