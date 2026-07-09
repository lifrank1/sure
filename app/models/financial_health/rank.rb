# League tiers for the financial fitness score (0-1000). Bronze is the floor
# tier — the "not started" state is covered by the provisional flag, not a
# lower tier. Promotion/demotion hysteresis (2 weeks above / 3 below) is a
# fast-follow once nightly snapshots build up history; v1 bands directly.
module FinancialHealth
  module Rank
    TIERS = [
      { key: :bronze,  min: 0 },
      { key: :silver,  min: 550 },
      { key: :gold,    min: 700 },
      { key: :diamond, min: 850 }
    ].freeze

    module_function

    def tier_for(total)
      return nil if total.nil?
      TIERS.reverse_each { |tier| return tier[:key] if total >= tier[:min] }
      :bronze
    end

    # [next_tier_key, points_needed] or nil when already Diamond.
    def next_tier(total)
      return nil if total.nil?
      upcoming = TIERS.find { |tier| tier[:min] > total }
      return nil if upcoming.nil?
      [ upcoming[:key], upcoming[:min] - total ]
    end

    # 0.0..1.0 progress through the current band (Diamond fills toward 1000).
    def band_progress(total)
      return 0.0 if total.nil?
      current = TIERS.reverse_each.find { |tier| total >= tier[:min] } || TIERS.first
      ceiling = TIERS.find { |tier| tier[:min] > total }&.fetch(:min) || 1000
      span = ceiling - current[:min]
      return 1.0 if span <= 0
      ((total - current[:min]).to_f / span).clamp(0.0, 1.0)
    end
  end
end
