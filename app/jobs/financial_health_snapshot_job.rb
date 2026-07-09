# Nightly financial fitness snapshot for every user with data, so score
# history (weekly deltas, future rank hysteresis) accrues even on days the
# user never opens /compare. Per-user failures are logged and skipped — one
# family's bad data must not stop the sweep.
class FinancialHealthSnapshotJob < ApplicationJob
  queue_as :scheduled

  def perform
    User.includes(:family).find_each do |user|
      snapshot_user(user)
    end
  end

  private
    def snapshot_user(user)
      family = user.family
      return if family.nil? || family.accounts.visible.none?

      result = FinancialHealth::Score.new(family, user: user).call
      FinancialHealth::Snapshot.record!(user: user, result: result)
    rescue => e
      Rails.logger.warn("FinancialHealthSnapshotJob failed for user #{user.id}: #{e.message}")
    end
end
