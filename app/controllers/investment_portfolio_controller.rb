class InvestmentPortfolioController < ApplicationController
  def show
    @investment_statement = Current.family.investment_statement
    @accounts = @investment_statement.investment_accounts.to_a

    @period = if params[:period].present? && Period.valid_key?(params[:period])
      Period.from_key(params[:period])
    else
      Period.from_key("last_90_days")
    end

    if @accounts.any?
      @balance_series = portfolio_series(@accounts, @period)
      @allocation = @investment_statement.allocation
      @period_totals = @investment_statement.totals(period: @period)
      @period_return_trend = @investment_statement.period_return_trend(period: @period)
      @period_flows = InvestmentFlowStatement.new(Current.family, user: Current.user).period_totals(period: @period)
    end

    @breadcrumbs = [ [ t("breadcrumbs.home"), root_path ], [ t("investment_portfolio.title"), nil ] ]
  end

  private
    def portfolio_series(accounts, period)
      builder = Balance::ChartSeriesBuilder.new(
        account_ids: accounts.map(&:id),
        currency: Current.family.currency,
        period: period,
        favorable_direction: "up"
      )
      builder.balance_series
    end
end
