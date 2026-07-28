# Loads recurring-charge management data for the Transactions "Upcoming"
# tab — absorbed from the deleted /recurring_transactions page
# (SIMPLIFICATION_PLAN 1c).
module RecurringManageable
  extend ActiveSupport::Concern

  private
    def load_recurring_management
      @recurring_transactions = Current.family.recurring_transactions
                                      .accessible_by(Current.user)
                                      .includes(:merchant)
                                      .order(status: :asc, next_expected_date: :asc)

      # Expected monthly outflow across active recurring charges (expenses
      # only), plus this month's paid vs still-to-pay
      active_charges = @recurring_transactions.select { |rt| rt.active? && !rt.transfer? && rt.amount.positive? }
      @monthly_recurring_total = Money.new(active_charges.sum(&:amount), Current.family.currency)
      @monthly_recurring_count = active_charges.size

      month_start = Date.current.beginning_of_month
      month_end = Date.current.end_of_month
      paid = active_charges.select { |rt| rt.last_occurrence_date.present? && rt.last_occurrence_date >= month_start }
      due = active_charges.select { |rt| rt.next_expected_date.present? && rt.next_expected_date <= month_end }
      @paid_so_far = Money.new(paid.sum(&:amount), Current.family.currency)
      @left_to_pay = Money.new(due.sum(&:amount), Current.family.currency)
    end
end
