# Daily consumption spending for a period — the series behind the dashboard
# "Monthly spending" pace chart. Mirrors IncomeStatement::Totals'
# transactions subquery (same kind/label/pending/tax-advantaged/account
# exclusions) grouped by entry date instead of category, restricted to
# expense-classified rows, and minus investment-contribution categories so
# the series sums to expense_split.spending — no two surfaces disagree.
class IncomeStatement::DailyExpenses
  def initialize(family, transactions_scope:, date_range:, included_account_ids: nil)
    @family = family
    @transactions_scope = transactions_scope
    @date_range = date_range
    @included_account_ids = included_account_ids
  end

  # => { Date => Float } (family currency), only days with spending
  def call
    return {} if @included_account_ids&.empty?

    ActiveRecord::Base.connection.select_all(query_sql).each_with_object({}) do |row, acc|
      acc[row["date"].to_date] = row["total"].to_f
    end
  end

  private
    def query_sql
      ActiveRecord::Base.sanitize_sql_array([ <<~SQL, sql_params ])
        SELECT
          ae.date,
          SUM(CASE WHEN at.kind IN ('investment_contribution', 'loan_payment') THEN ABS(ae.amount * COALESCE(er.rate, 1)) ELSE ae.amount * COALESCE(er.rate, 1) END) as total
        FROM (#{@transactions_scope.to_sql}) at
        JOIN entries ae ON ae.entryable_id = at.id AND ae.entryable_type = 'Transaction'
        JOIN accounts a ON a.id = ae.account_id
        LEFT JOIN categories c ON c.id = at.category_id
        LEFT JOIN categories pc ON pc.id = c.parent_id
        LEFT JOIN exchange_rates er ON (
          er.date = ae.date AND
          er.from_currency = ae.currency AND
          er.to_currency = :target_currency
        )
        WHERE at.kind NOT IN (#{budget_excluded_kinds_sql})
          AND (
            at.investment_activity_label IS NULL
            OR at.investment_activity_label NOT IN ('Transfer', 'Sweep In', 'Sweep Out', 'Exchange')
          )
          AND ae.excluded = false
          AND a.family_id = :family_id
          AND a.status IN ('draft', 'active')
          AND (at.kind IN ('investment_contribution', 'loan_payment') OR ae.amount >= 0)
          AND (c.id IS NULL OR (c.name NOT IN (:investment_contribution_names) AND (pc.name IS NULL OR pc.name NOT IN (:investment_contribution_names))))
          #{exclude_tax_advantaged_sql}
          #{include_finance_accounts_sql}
        GROUP BY ae.date
        ORDER BY ae.date;
      SQL
    end

    def sql_params
      params = {
        target_currency: @family.currency,
        family_id: @family.id,
        investment_contribution_names: Category.all_investment_contributions_names
      }

      ids = @family.tax_advantaged_account_ids
      params[:tax_advantaged_account_ids] = ids if ids.present?
      params[:included_account_ids] = @included_account_ids if @included_account_ids

      params
    end

    def exclude_tax_advantaged_sql
      return "" if @family.tax_advantaged_account_ids.empty?
      "AND a.id NOT IN (:tax_advantaged_account_ids)"
    end

    def include_finance_accounts_sql
      return "" if @included_account_ids.nil?
      "AND a.id IN (:included_account_ids)"
    end

    def budget_excluded_kinds_sql
      Transaction::BUDGET_EXCLUDED_KINDS.map { |k| "'#{k}'" }.join(", ")
    end
end
