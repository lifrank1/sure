# Computes a user's savings rate from linked accounts, for the "How you
# compare" feature.
#
# v1 definition (take-home): rate = (income − spending) ÷ income, over a
# trailing window. "spending" is consumption only (ExpenseSplit#spending
# already excludes money moved into investments), so dollars a user routes to a
# brokerage count as saved, not spent — no balance-flow decomposition needed.
#
# Known limitation: payroll 401(k) withheld before the paycheck hits the bank
# is invisible here (the deposit is already net of it), so this is a TAKE-HOME
# rate. When a retirement account is linked we can add those contributions; the
# UI prompts for that. Kept explicit rather than silently wrong.
class SavingsRate
  Result = Data.define(:rate, :income, :spending, :saved, :take_home_only) do
    def computable? = !rate.nil?
    def percent = rate ? (rate * 100).round : nil
  end

  def initialize(family, user: nil, period: Period.last_30_days)
    @family = family
    @user = user
    @period = period
  end

  def call
    stmt = @family.income_statement(user: @user)
    income = stmt.income_totals(period: @period).total.to_f
    spending = stmt.expense_split(period: @period).spending.amount.to_f

    return Result.new(rate: nil, income: income, spending: spending, saved: nil, take_home_only: true) if income <= 0

    saved = income - spending
    rate = (saved / income).clamp(-1.0, 1.0)

    Result.new(rate: rate, income: income, spending: spending, saved: saved, take_home_only: !retirement_linked?)
  rescue => e
    Rails.logger.warn("SavingsRate failed: #{e.message}")
    Result.new(rate: nil, income: 0, spending: 0, saved: nil, take_home_only: true)
  end

  private
    # Does the user have a linked retirement/investment account? Drives whether
    # we label the rate "take-home" and whether we prompt to link a 401(k).
    def retirement_linked?
      @family.accounts.visible.where(accountable_type: %w[Investment Crypto]).exists?
    end
end
