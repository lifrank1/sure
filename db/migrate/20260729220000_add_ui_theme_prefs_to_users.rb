class AddUiThemePrefsToUsers < ActiveRecord::Migration[7.2]
  def change
    # Three-axis look system (UiTheme). Columns rather than the preferences
    # JSONB because the layout reads all three on every single request.
    add_column :users, :ui_palette, :string, default: "graphite", null: false
    add_column :users, :ui_typeface, :string, default: "geist", null: false
    add_column :users, :ui_style, :string, default: "refined", null: false
  end
end
