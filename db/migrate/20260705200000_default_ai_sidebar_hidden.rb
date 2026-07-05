class DefaultAiSidebarHidden < ActiveRecord::Migration[7.2]
  # The AI chat sidebar reserves ~25% of every page's width. Hosted-product
  # decision: start collapsed for everyone; the header panel-right toggle
  # reopens it per-user at any time.
  def up
    change_column_default :users, :show_ai_sidebar, from: true, to: false
    execute "UPDATE users SET show_ai_sidebar = FALSE"
  end

  def down
    change_column_default :users, :show_ai_sidebar, from: false, to: true
  end
end
