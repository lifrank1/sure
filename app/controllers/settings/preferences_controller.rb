class Settings::PreferencesController < ApplicationController
  layout "settings"

  def show
    @user = Current.user
  end

  # Writes per-user boolean preferences stored in the JSONB `users.preferences`
  # column. Mirrors Settings::AppearancesController#update so the toggle card on
  # the Preferences page can submit directly without going through the broader
  # UsersController#update flow (which expects a full user form payload).
  def update
    @user = Current.user
    user_params = params.permit(user: [ :preview_features_enabled, :ai_enabled ]).fetch(:user, {})

    @user.transaction do
      @user.lock!
      updated_prefs = (@user.preferences || {}).deep_dup
      if user_params.key?(:preview_features_enabled)
        updated_prefs["preview_features_enabled"] =
          ActiveModel::Type::Boolean.new.cast(user_params[:preview_features_enabled])
      end
      # ai_enabled is a real column, not a JSONB preference — write it
      # directly (this backs the user-facing AI on/off toggle now that the
      # AI Prompts operator page is super_admin-only).
      attrs = { preferences: updated_prefs }
      if user_params.key?(:ai_enabled)
        attrs[:ai_enabled] = ActiveModel::Type::Boolean.new.cast(user_params[:ai_enabled])
      end
      @user.update!(**attrs)
    end
    redirect_to settings_preferences_path
  end
end
