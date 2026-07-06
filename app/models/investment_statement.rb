require "digest/md5"

class InvestmentStatement
  include Monetizable

  monetize :total_contributions, :total_dividends, :total_interest, :unrealized_gains

  attr_reader :family, :user

  def initialize(family, user: nil)
    @family = family
    @user = user || Current.user
  end

  # Get totals for a specific period
  def totals(period: Period.current_month)
    trades_in_period = family.trades
      .joins(:entry)
      .where(entries: { date: period.date_range, account_id: investment_account_ids })

    result = totals_query(trades_scope: trades_in_period)

    PeriodTotals.new(
      contributions: Money.new(result[:contributions], family.currency),
      withdrawals: Money.new(result[:withdrawals], family.currency),
      dividends: Money.new(result[:dividends], family.currency),
      interest: Money.new(result[:interest], family.currency),
      trades_count: result[:trades_count],
      currency: family.currency
    )
  end

  # Net contributions (contributions - withdrawals)
  def net_contributions(period: Period.current_month)
    t = totals(period: period)
    t.contributions - t.withdrawals
  end

  # Total portfolio value across all investment accounts
  def portfolio_value
    investment_accounts.sum { |a| convert_to_family_currency(a.balance, a.currency) }
  end

  def portfolio_value_money
    Money.new(portfolio_value, family.currency)
  end

  # Total cash in investment accounts
  def cash_balance
    investment_accounts.sum { |a| convert_to_family_currency(a.cash_balance, a.currency) }
  end

  def cash_balance_money
    Money.new(cash_balance, family.currency)
  end

  # Total holdings value
  def holdings_value
    portfolio_value - cash_balance
  end

  def holdings_value_money
    Money.new(holdings_value, family.currency)
  end

  # All current holdings across investment accounts. Holdings are returned in
  # their native currency; callers that aggregate across accounts must convert
  # to family currency via convert_to_family_currency.
  def current_holdings
    return Holding.none unless investment_accounts.any?

    # Get the latest holding for each security per account
    Holding
      .where(account_id: investment_account_ids)
      .where.not(qty: 0)
      .where(
        id: Holding
          .where(account_id: investment_account_ids)
          .select("DISTINCT ON (holdings.account_id, holdings.security_id) holdings.id")
          .order(Arel.sql("holdings.account_id, holdings.security_id, holdings.date DESC"))
      )
      .includes(:security, :account)
  end

  # Top holdings by family-currency value, aggregated by security across accounts
  def top_holdings(limit: 5)
    allocation.first(limit)
  end

  # Portfolio allocation by security, aggregated across accounts (the same
  # security held in two accounts renders as one position). Weights and amounts
  # are computed in the family's currency so cross-currency holdings compare
  # correctly, and weights are relative to total holdings value so they sum
  # to 100% portfolio-wide rather than per account.
  def allocation
    grouped = current_holdings.to_a.group_by(&:security_id).values

    converted = grouped.map do |holdings|
      [ holdings, holdings.sum { |h| convert_to_family_currency(h.amount, h.currency) } ]
    end

    total = converted.sum { |_, value| value }
    return [] if total.zero?

    converted
      .sort_by { |_, value| -value }
      .map do |holdings, value|
        HoldingAllocation.new(
          security: holdings.first.security,
          amount: Money.new(value, family.currency),
          weight: (value / total * 100).round(2),
          trend: aggregated_holding_trend(holdings),
          accounts_count: holdings.map(&:account_id).uniq.size
        )
      end
  end

  # Unrealized gains across all holdings, summed in family currency
  def unrealized_gains
    current_holdings.sum do |holding|
      trend = holding.trend
      trend ? convert_to_family_currency(trend.value, holding.currency) : 0
    end
  end

  # Total contributions (all time) - returns numeric for monetize
  def total_contributions
    all_time_totals.contributions&.amount || 0
  end

  # Total dividends (all time) - returns numeric for monetize
  def total_dividends
    all_time_totals.dividends&.amount || 0
  end

  # Total interest (all time) - returns numeric for monetize
  def total_interest
    all_time_totals.interest&.amount || 0
  end

  def unrealized_gains_trend
    holdings = current_holdings.to_a
    return nil if holdings.empty?

    # Only include holdings with known cost basis in the calculation
    holdings_with_cost_basis = holdings.select(&:avg_cost)
    return nil if holdings_with_cost_basis.empty?

    current = holdings_with_cost_basis.sum do |h|
      convert_to_family_currency(h.amount, h.currency)
    end
    previous = holdings_with_cost_basis.sum do |h|
      convert_to_family_currency(h.qty * h.avg_cost.amount, h.currency)
    end

    Trend.new(
      current: Money.new(current, family.currency),
      previous: Money.new(previous, family.currency)
    )
  end

  def period_return_trend(period: Period.current_month)
    currency = family.currency
    account_ids = investment_account_ids
    return nil if account_ids.empty?

    # The EXISTS clause only counts a day's market flows when the account
    # already carried a meaningful balance (>= 1 unit) the previous day.
    # Provider lifecycle noise (first sync, holdings dropping to ~$0 dust and
    # re-materializing) otherwise books the account's whole value as a one-day
    # "market gain" — a 401k backfill once showed up as a +31% month.
    # NB: no `--` comments inside the heredoc — .squish would fold the rest
    # of the query into the comment.
    absolute_return = ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql_array([
        <<~SQL.squish,
          SELECT COALESCE(SUM(b.net_market_flows * COALESCE(er.rate, 1)), 0)
          FROM balances b
          JOIN accounts a ON a.id = b.account_id
          LEFT JOIN exchange_rates er ON (
            er.date = b.date
            AND er.from_currency = b.currency
            AND er.to_currency = :currency
          )
          WHERE a.id IN (:account_ids)
            AND a.family_id = :family_id
            AND a.status IN ('draft', 'active')
            AND b.date BETWEEN :start_date AND :end_date
            AND EXISTS (
              SELECT 1 FROM balances b_prev
              WHERE b_prev.account_id = b.account_id
                AND b_prev.date = b.date - 1
                AND ABS(b_prev.balance) >= 1
            )
        SQL
        {
          currency: currency,
          account_ids: account_ids,
          family_id: family.id,
          start_date: period.date_range.begin,
          end_date: period.date_range.end
        }
      ])
    ).to_d

    period_start = period.date_range.begin

    # Single query for all accounts' most recent pre-period balance (strict < to avoid
    # double-counting the first day's net_market_flows in both the denominator and absolute_return).
    # FX conversion is done in SQL (matching absolute_return) so balance rows whose currency
    # differs from the account's current currency (e.g. after a currency change) are still picked up.
    start_value = ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql_array([
        <<~SQL.squish,
          SELECT COALESCE(SUM(b.end_balance * COALESCE(er.rate, 1)), 0)
          FROM accounts a
          INNER JOIN balances b ON b.account_id = a.id
          LEFT JOIN exchange_rates er ON (
            er.date = :period_start
            AND er.from_currency = b.currency
            AND er.to_currency = :currency
          )
          INNER JOIN (
            SELECT b2.account_id, MAX(b2.date) AS max_date
            FROM balances b2
            WHERE b2.account_id IN (:account_ids)
              AND b2.date < :period_start
            GROUP BY b2.account_id
          ) latest ON latest.account_id = b.account_id AND b.date = latest.max_date
          WHERE a.id IN (:account_ids)
            AND a.family_id = :family_id
            AND a.status IN ('draft', 'active')
        SQL
        { account_ids: account_ids, period_start: period_start, family_id: family.id, currency: currency }
      ])
    ).to_d

    return nil if start_value.zero?

    Trend.new(
      current: Money.new(start_value + absolute_return, currency),
      previous: Money.new(start_value, currency)
    )
  end

  # Unrealized + realized gains grouped by account tax treatment (taxable,
  # tax_deferred, tax_exempt, tax_advantaged). Realized gains come from sell
  # trades within the period. Moved here from ReportsController so the
  # investments page and the print report share one implementation.
  def gains_by_tax_treatment(period: Period.current_month)
    currency = family.currency
    # Eager-load account and accountable to avoid N+1 when accessing tax_treatment
    holdings_list = current_holdings
      .includes(account: :accountable)
      .to_a

    holdings_by_treatment = holdings_list.group_by { |h| h.account.tax_treatment || :taxable }

    # Sell trades in period with realized gains
    sell_trades = family.trades
      .joins(:entry)
      .where(entries: { date: period.date_range })
      .where("trades.qty < 0")
      .includes(:security, entry: { account: :accountable })
      .to_a

    # Preload holdings for all accounts that have sell trades to avoid N+1 in realized_gain_loss
    account_ids = sell_trades.map { |t| t.entry.account_id }.uniq
    holdings_by_account = Holding
      .where(account_id: account_ids)
      .where("date <= ?", period.date_range.end)
      .order(date: :desc)
      .group_by(&:account_id)

    sell_trades.each do |trade|
      trade.instance_variable_set(:@preloaded_holdings, holdings_by_account[trade.entry.account_id] || [])
    end

    trades_by_treatment = sell_trades.group_by { |t| t.entry.account.tax_treatment || :taxable }

    # Unwrap helper: Trend#value / realized_gain_loss#value are Money objects,
    # and this codebase's Money keeps the source currency through `*` and
    # through `Money.new(money, _)`. Unwrapping to BigDecimal first keeps sums
    # and the final Money.new(..., currency) correctly labeled in family currency.
    to_numeric = ->(value) { value.is_a?(Money) ? value.amount : value }

    # Unrealized gains mark holdings to market, so convert at today's FX.
    foreign_holding_currencies = holdings_list.map(&:currency).compact.uniq.reject { |c| c == currency }
    holding_rates = ExchangeRate.rates_for(foreign_holding_currencies, to: currency, date: Date.current)
    convert_current = ->(amount, from) {
      numeric = to_numeric.call(amount)
      from == currency ? numeric : numeric * (holding_rates[from] || 1)
    }

    # Realized gains are locked at trade time, so convert each at its own
    # entry-date FX. Mirrors InvestmentStatement::Totals, which also uses
    # entry-date rates for contributions/withdrawals.
    foreign_trade_currencies = sell_trades.map(&:currency).compact.uniq.reject { |c| c == currency }
    rates_by_trade_date = sell_trades.map { |t| t.entry.date }.uniq.each_with_object({}) do |date, memo|
      memo[date] = ExchangeRate.rates_for(foreign_trade_currencies, to: currency, date: date)
    end
    convert_trade = ->(amount, from, date) {
      numeric = to_numeric.call(amount)
      from == currency ? numeric : numeric * (rates_by_trade_date.dig(date, from) || 1)
    }

    %i[taxable tax_deferred tax_exempt tax_advantaged].each_with_object({}) do |treatment, hash|
      holdings = holdings_by_treatment[treatment] || []
      trades = trades_by_treatment[treatment] || []

      unrealized = holdings.sum do |h|
        trend = h.trend
        trend ? convert_current.call(trend.value, h.currency) : 0
      end

      realized = trades.sum do |t|
        gain = t.realized_gain_loss
        gain ? convert_trade.call(gain.value, t.currency, t.entry.date) : 0
      end

      # Only include treatment groups that have some activity
      next if holdings.empty? && trades.empty?

      hash[treatment] = {
        holdings: holdings,
        sell_trades: trades,
        unrealized_gain: Money.new(unrealized, currency),
        realized_gain: Money.new(realized, currency),
        total_gain: Money.new(unrealized + realized, currency)
      }
    end
  end

  # Day change across portfolio, summed in family currency
  def day_change
    changes = current_holdings.to_a.filter_map do |h|
      t = h.day_change
      next nil unless t
      curr = t.current.is_a?(Money) ? t.current.amount : t.current
      prev = t.previous.is_a?(Money) ? t.previous.amount : t.previous
      [
        convert_to_family_currency(curr, h.currency),
        convert_to_family_currency(prev, h.currency)
      ]
    end

    return nil if changes.empty?

    Trend.new(
      current: Money.new(changes.sum { |c, _| c }, family.currency),
      previous: Money.new(changes.sum { |_, p| p }, family.currency)
    )
  end

  # Investment accounts
  def investment_accounts
    @investment_accounts ||= begin
      scope = family.accounts.visible.where(accountable_type: %w[Investment Crypto])
      scope = scope.included_in_finances_for(user) if user
      scope
    end
  end

  private
    # Today's rates for every currency present on the family's investment
    # accounts and their holdings. Mirrors BalanceSheet::AccountTotals#exchange_rates.
    def exchange_rates
      @exchange_rates ||= begin
        account_currencies = investment_accounts.map(&:currency)
        holding_currencies = Holding.where(account_id: investment_account_ids).distinct.pluck(:currency)
        foreign = (account_currencies + holding_currencies)
                    .compact
                    .uniq
                    .reject { |c| c == family.currency }
        ExchangeRate.rates_for(foreign, to: family.currency, date: Date.current)
      end
    end

    # Unwrap Money first because this codebase's Money (lib/money.rb) ignores
    # the currency arg of `Money.new` when the payload is already a Money, and
    # `Money * numeric` preserves the source currency — so multiplying a
    # foreign-currency Money by a rate would FX-scale the amount but keep the
    # wrong currency label, corrupting downstream sums.
    def convert_to_family_currency(amount, from_currency)
      return amount if amount.nil?
      numeric = amount.is_a?(Money) ? amount.amount : amount
      return numeric if from_currency == family.currency
      rate = exchange_rates[from_currency] || 1
      numeric * rate
    end

    def all_time_totals
      @all_time_totals ||= totals(period: Period.all_time)
    end

    PeriodTotals = Data.define(:contributions, :withdrawals, :dividends, :interest, :trades_count, :currency) do
      def net_flow
        contributions - withdrawals
      end

      def total_income
        dividends + interest
      end
    end

    HoldingAllocation = Data.define(:security, :amount, :weight, :trend, :accounts_count) do
      def ticker
        security.ticker
      end

      def name
        security.name || ticker
      end

      def amount_money
        amount
      end
    end

    # Cost-basis trend for one security summed across the accounts holding it.
    # Mirrors unrealized_gains_trend: only holdings with a known cost basis
    # participate; nil when none have one (return genuinely unknown).
    def aggregated_holding_trend(holdings)
      with_cost_basis = holdings.select(&:avg_cost)
      return nil if with_cost_basis.empty?

      current = with_cost_basis.sum { |h| convert_to_family_currency(h.amount, h.currency) }
      previous = with_cost_basis.sum { |h| convert_to_family_currency(h.qty * h.avg_cost.amount, h.currency) }
      return nil if previous.zero?

      Trend.new(
        current: Money.new(current, family.currency),
        previous: Money.new(previous, family.currency)
      )
    end

    def investment_account_ids
      @investment_account_ids ||= investment_accounts.pluck(:id)
    end

    def totals_query(trades_scope:)
      sql_hash = Digest::MD5.hexdigest(trades_scope.to_sql)

      Rails.cache.fetch([
        "investment_statement", "totals_query", family.id, user&.id, sql_hash, family.entries_cache_version
      ]) { Totals.new(family, trades_scope: trades_scope).call }
    end

    def monetizable_currency
      family.currency
    end
end
