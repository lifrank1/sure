# Instance-wide signup funnel for the super_admin Instance page:
# signed up → linked an institution → active in week 2. Reads users +
# user_days + provider items; whole-table is fine at hobby scale (the page
# is super_admin-only and renders a handful of rows).
class FunnelReport
  Row = Data.define(:user, :signed_up_on, :linked, :week1_days, :week2_retained, :last_active_on)

  def rows
    User.includes(:family).order(:created_at).map do |user|
      signup = user.created_at.to_date
      days = active_days_by_user[user.id] || []

      Row.new(
        user: user,
        signed_up_on: signup,
        linked: linked_family_ids.include?(user.family_id),
        week1_days: days.count { |d| d > signup && d <= signup + 7 },
        week2_retained: days.any? { |d| d > signup + 7 && d <= signup + 14 },
        last_active_on: days.max
      )
    end
  end

  private
    def active_days_by_user
      @active_days_by_user ||= UserDay.group(:user_id).pluck(:user_id, Arel.sql("array_agg(date)")).to_h
    end

    def linked_family_ids
      @linked_family_ids ||= PlaidItem.distinct.pluck(:family_id) |
        SnaptradeItem.distinct.pluck(:family_id) |
        SimplefinItem.distinct.pluck(:family_id)
    end
end
