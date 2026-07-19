# Instance-operator pages (AI config, LLM costs, API keys, MCP): the
# plumbing belongs to whoever runs the instance, not family admins. Keep in
# sync with the matching `if:` conditions in settings/_settings_nav and
# SettingsHelper::SETTINGS_ORDER.
module SuperAdminGated
  extend ActiveSupport::Concern

  included do
    before_action :ensure_super_admin
  end

  private
    def ensure_super_admin
      unless Current.user&.super_admin?
        redirect_to settings_preferences_path, alert: t("settings.hostings.update.not_authorized", default: "Not authorized")
      end
    end
end
