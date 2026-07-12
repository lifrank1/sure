class AddConfirmedAtToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :confirmed_at, :datetime

    # Everyone who signed up before signup verification existed is
    # grandfathered — they're already using the app and blocking them
    # retroactively would only lock people out.
    execute "UPDATE users SET confirmed_at = NOW() WHERE confirmed_at IS NULL"
  end

  def down
    remove_column :users, :confirmed_at
  end
end
