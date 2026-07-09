# One scored day per user. Written lazily on /compare visits and densified by
# the nightly FinancialHealthSnapshotJob; history powers the weekly delta chip
# and, later, rank promotion/demotion hysteresis.
module FinancialHealth
  class Snapshot < ApplicationRecord
    self.table_name = "financial_health_snapshots"

    belongs_to :family
    belongs_to :user

    validates :date, presence: true, uniqueness: { scope: :user_id }
    validates :total, presence: true

    class << self
      def record!(user:, result:)
        return nil unless result.computable?

        snapshot = find_or_initialize_by(user_id: user.id, date: Date.current)
        snapshot.family_id = user.family_id
        snapshot.total = result.total
        snapshot.rank = result.rank.to_s
        snapshot.pillars = result.pillars.map do |p|
          { "key" => p.key.to_s, "score" => p.score&.round(1), "available" => p.available? }
        end
        snapshot.save!
        snapshot
      end

      # Points moved since ~a week ago; nil until enough history exists.
      def weekly_delta(user)
        today = find_by(user_id: user.id, date: Date.current)
        return nil if today.nil?

        prior = where(user_id: user.id)
          .where(date: ..7.days.ago.to_date)
          .order(date: :desc)
          .first
        return nil if prior.nil?

        today.total - prior.total
      end
    end
  end
end
