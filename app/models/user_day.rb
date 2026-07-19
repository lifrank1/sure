# One row per user per active day — the minimal instrument behind the
# Instance-page funnel (signup → linked → retained). Written from
# ApplicationController#record_user_day at most once per request and
# throttled through Rails.cache, so the hot path is one cache hit.
class UserDay < ApplicationRecord
  belongs_to :user

  def self.record!(user, date: Date.current)
    insert_all([ { user_id: user.id, date: date } ], unique_by: [ :user_id, :date ])
  end
end
