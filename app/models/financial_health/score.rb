# Composite 0-1000 "financial fitness" score behind the league ranks on
# /compare. Behavior-weighted by design: it scores how you run your money
# (saving, buffer, debt load, trend, hygiene), NOT how much you have — wealth
# level is the /compare percentile card's job. That choice is what makes the
# rank movable for a student and keeps a high earner with bad habits out of
# Diamond.
#
# Each pillar maps a raw metric through Curve anchors calibrated so "typical
# behavior" lands near 50; the weighted composite is therefore roughly
# centered, and Rank bands it. Pillars with missing data are marked
# unavailable and their weight is renormalized away — never scored as zero.
# All inputs are read via the same statement objects the rest of the app uses
# (IncomeStatement, BalanceSheet), so market moves never leak in: income and
# spending exclude trades, and Momentum compares saved cash, not balances.
module FinancialHealth
  class Score
    WEIGHTS = {
      save: 0.25,
      buffer: 0.25,
      debt: 0.20,
      momentum: 0.20,
      habits: 0.10
    }.freeze

    # Anchors: [ raw, score ] pairs, see Curve. Calibration notes:
    # - save: FRED personal saving rate ~3-5% => national-typical ~50
    # - buffer: months of spending in liquid cash; 3mo is the classic target
    # - debt: revolving (credit card) balance as a share of liquid cash
    # - momentum: this month's net saved vs the prior two months' average,
    #   normalized by monthly income
    SAVE_ANCHORS     = [ [ -25, 5 ], [ 0, 30 ], [ 5, 50 ], [ 10, 65 ], [ 20, 85 ], [ 35, 97 ] ].freeze
    BUFFER_ANCHORS   = [ [ 0, 5 ], [ 0.5, 30 ], [ 1, 50 ], [ 3, 80 ], [ 6, 95 ] ].freeze
    DEBT_ANCHORS     = [ [ 0, 95 ], [ 0.1, 85 ], [ 0.3, 70 ], [ 1.0, 45 ], [ 2.0, 25 ], [ 4.0, 10 ] ].freeze
    MOMENTUM_ANCHORS = [ [ -0.5, 10 ], [ -0.15, 30 ], [ 0, 50 ], [ 0.15, 70 ], [ 0.5, 90 ] ].freeze

    PROVISIONAL_HISTORY_DAYS = 30

    # Renormalizing away missing pillars is fine at the margin, but a rank
    # must not rest on a sliver of signal (e.g. Habits alone scoring Gold with
    # zero financial data). Below this much available weight, no score.
    MIN_AVAILABLE_WEIGHT = 0.5

    Pillar = Data.define(:key, :score, :weight, :available, :raw) do
      def available? = available
    end

    Result = Data.define(:total, :pillars, :provisional) do
      def provisional? = provisional
      def rank = Rank.tier_for(total)
      def computable? = !total.nil?

      def weakest_pillar
        pillars.select(&:available?).min_by(&:score)
      end
    end

    def initialize(family, user: nil)
      @family = family
      @user = user
    end

    def call
      pillars = [ save_pillar, buffer_pillar, debt_pillar, momentum_pillar, habits_pillar ]
      Result.new(total: composite(pillars), pillars: pillars, provisional: provisional?)
    end

    private
      def composite(pillars)
        available = pillars.select(&:available?)
        return nil if available.empty?

        weight_sum = available.sum(&:weight)
        return nil if weight_sum < MIN_AVAILABLE_WEIGHT

        weighted = available.sum { |p| p.score * p.weight }
        ((weighted / weight_sum) * 10).round.clamp(0, 1000)
      end

      def provisional?
        @family.oldest_entry_date > PROVISIONAL_HISTORY_DAYS.days.ago.to_date
      end

      def income_statement
        @income_statement ||= @family.income_statement(user: @user)
      end

      def balance_sheet
        @balance_sheet ||= @family.balance_sheet(user: @user)
      end

      def net_saved(period)
        income = income_statement.income_totals(period: period).total.to_f
        spending = income_statement.expense_split(period: period).spending.amount.to_f
        income - spending
      end

      def asset_group_total(accountable_type)
        group = balance_sheet.assets.account_groups.find { |g| g.accountable_type == accountable_type }
        (group&.total || 0).to_f
      end

      def liability_group_total(accountable_type)
        group = balance_sheet.liabilities.account_groups.find { |g| g.accountable_type == accountable_type }
        (group&.total || 0).to_f
      end

      def liquid_cash
        @liquid_cash ||= asset_group_total("Depository")
      end

      def pillar(key, score:, raw: nil)
        Pillar.new(key: key, score: score.to_f.clamp(0, 100), weight: WEIGHTS.fetch(key), available: true, raw: raw)
      end

      def unavailable(key)
        Pillar.new(key: key, score: nil, weight: WEIGHTS.fetch(key), available: false, raw: nil)
      end

      # ---- Save: 90-day take-home savings rate ----
      def save_pillar
        result = SavingsRate.new(@family, user: @user, period: Period.last_90_days).call
        return unavailable(:save) unless result.computable?

        pillar(:save, score: Curve.score(result.percent, SAVE_ANCHORS), raw: result.percent)
      end

      # ---- Buffer: months of typical spending covered by liquid cash ----
      def buffer_pillar
        return unavailable(:buffer) unless @family.accounts.visible.where(accountable_type: "Depository").exists?

        monthly_spend = income_statement.expense_split(period: Period.last_90_days).spending.amount.to_f / 3.0
        return unavailable(:buffer) if monthly_spend <= 0

        months = liquid_cash / monthly_spend
        pillar(:buffer, score: Curve.score(months, BUFFER_ANCHORS), raw: months.round(2))
      end

      # ---- Debt: revolving balance vs liquid cash ----
      # Requires a linked liability account: with none we cannot distinguish
      # debt-free from not-linked, so the pillar stays locked rather than
      # handing out a free high score.
      def debt_pillar
        has_liability = @family.accounts.visible.where(accountable_type: [ "CreditCard", "Loan" ]).exists?
        return unavailable(:debt) unless has_liability

        revolving = liability_group_total("CreditCard")
        ratio =
          if liquid_cash > 0
            revolving / liquid_cash
          else
            revolving > 0 ? DEBT_ANCHORS.last[0] : 0
          end
        pillar(:debt, score: Curve.score(ratio, DEBT_ANCHORS), raw: ratio.round(2))
      end

      # ---- Momentum: is net saved trending up vs the prior two months? ----
      def momentum_pillar
        today = Date.current
        income_90 = income_statement.income_totals(period: Period.last_90_days).total.to_f
        return unavailable(:momentum) if income_90 <= 0

        current = net_saved(Period.custom(start_date: today - 29, end_date: today))
        prior_a = net_saved(Period.custom(start_date: today - 59, end_date: today - 30))
        prior_b = net_saved(Period.custom(start_date: today - 89, end_date: today - 60))

        baseline = (prior_a + prior_b) / 2.0
        monthly_income = [ income_90 / 3.0, 1.0 ].max
        delta_ratio = (current - baseline) / monthly_income

        pillar(:momentum, score: Curve.score(delta_ratio, MOMENTUM_ANCHORS), raw: delta_ratio.round(3))
      end

      # ---- Habits: four hygiene checks, 25 points each ----
      def habits_pillar
        return unavailable(:habits) unless @family.accounts.visible.exists?

        score = budget_points + review_points + categorized_points + freshness_points
        pillar(:habits, score: score, raw: score)
      end

      def budget_points
        budget = @family.budgets.where("start_date <= :today AND end_date >= :today", today: Date.current).first
        return 0 if budget.nil?
        budget.budget_categories.where.not(budgeted_spending: nil).exists? ? 25 : 5
      end

      def review_points
        count = @family.transactions.to_review.count
        return 25 if count.zero?
        count < 10 ? 12 : 0
      end

      def categorized_points
        scope = @family.transactions.visible
          .where.not(kind: Transaction::TRANSFER_KINDS)
          .where(entries: { date: 30.days.ago.to_date.. })
        total = scope.count
        return 25 if total.zero?

        rate = 1.0 - (scope.where(category_id: nil).count.to_f / total)
        if rate >= 0.9 then 25
        elsif rate >= 0.7 then 15
        else 5
        end
      end

      def freshness_points
        return 25 unless @family.accounts.visible.joins(:account_providers).exists?

        synced_at = @family.latest_sync_completed_at
        return 0 if synced_at.nil?
        synced_at >= 7.days.ago ? 25 : 10
      end
  end
end
