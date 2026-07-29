class Settings::AppearancesController < ApplicationController
  layout "settings"

  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    @user.transaction do
      @user.lock!
      updated_prefs = (@user.preferences || {}).deep_dup
      updated_prefs["show_split_grouped"] = params.dig(:user, :show_split_grouped) == "1" if params.dig(:user, :show_split_grouped)
      updated_prefs["dashboard_two_column"] = params.dig(:user, :dashboard_two_column) == "1" if params.dig(:user, :dashboard_two_column)
      @user.update!(preferences: updated_prefs)
    end
    redirect_to settings_appearance_path
  end

  # "Surprise me" — every axis combination is valid by construction, so this is
  # just a sample. Server-side so the pickers, the <html> attributes and the
  # persisted record can never disagree.
  def randomize
    Current.user.update!(UiTheme.random_combination.transform_keys { |axis| :"ui_#{axis}" })
    redirect_to settings_appearance_path, notice: t(".randomized")
  end

  def reset
    Current.user.update!(
      ui_palette: UiTheme.default_for(:palette),
      ui_typeface: UiTheme.default_for(:typeface),
      ui_style: UiTheme.default_for(:style)
    )
    redirect_to settings_appearance_path, notice: t(".reset")
  end
end
