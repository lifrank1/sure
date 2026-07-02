# Controls which connection providers are visible in the UI.
#
# Set ENABLED_PROVIDERS to a comma-separated list of provider keys
# (e.g. "plaid,snaptrade") to show only those providers in the
# add-account flow and the Settings > Providers page. A key enables
# all regional variants via prefix match ("plaid" covers "plaid_us"
# and "plaid_eu"). Leave unset/blank to show every provider
# (upstream default behavior).
class Provider::Visibility
  class << self
    def enabled?(key)
      return true if enabled_keys.empty?

      normalized = key.to_s.downcase
      enabled_keys.any? { |e| normalized == e || normalized.start_with?("#{e}_") }
    end

    def enabled_keys
      @enabled_keys ||= ENV["ENABLED_PROVIDERS"].to_s.split(",").map { |k| k.strip.downcase }.reject(&:empty?)
    end

    # Allows tests to re-read the environment
    def reset!
      @enabled_keys = nil
    end
  end
end
