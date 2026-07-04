class SnaptradeAccount::Processor
  include SnaptradeAccount::DataHelpers

  attr_reader :snaptrade_account

  def initialize(snaptrade_account)
    @snaptrade_account = snaptrade_account
  end

  def process
    account = snaptrade_account.current_account
    return unless account

    Rails.logger.info "SnaptradeAccount::Processor - Processing account #{snaptrade_account.id} -> Sure account #{account.id}"

    # Update account balance FIRST (before processing holdings/activities)
    # This creates the current_anchor valuation needed for reverse sync
    update_account_balance(account)

    # Process holdings
    holdings_count = snaptrade_account.raw_holdings_payload&.size || 0
    Rails.logger.info "SnaptradeAccount::Processor - Holdings payload has #{holdings_count} items"

    # Run the holdings processor when there are security holdings OR
    # non-primary-currency cash to surface as synthetic cash holdings (#1809).
    if snaptrade_account.raw_holdings_payload.present? || snaptrade_account.non_primary_cash_entries.any?
      Rails.logger.info "SnaptradeAccount::Processor - Processing holdings..."
      SnaptradeAccount::HoldingsProcessor.new(snaptrade_account).process
    else
      Rails.logger.warn "SnaptradeAccount::Processor - No holdings payload to process"
    end

    # Process activities (trades, dividends, etc.)
    activities_count = snaptrade_account.raw_activities_payload&.size || 0
    Rails.logger.info "SnaptradeAccount::Processor - Activities payload has #{activities_count} items"

    if snaptrade_account.raw_activities_payload.present?
      Rails.logger.info "SnaptradeAccount::Processor - Processing activities..."
      SnaptradeAccount::ActivitiesProcessor.new(snaptrade_account).process
    else
      Rails.logger.warn "SnaptradeAccount::Processor - No activities payload to process"
    end

    # Trigger immediate UI refresh so entries appear in the activity feed
    # This is critical for fresh account links where the sync complete broadcast
    # might be delayed by child syncs (balance calculations)
    account.broadcast_sync_complete
    Rails.logger.info "SnaptradeAccount::Processor - Broadcast sync complete for account #{account.id}"

    { holdings_processed: holdings_count > 0, activities_processed: activities_count > 0 }
  end

  private

    def update_account_balance(account)
      # Calculate total balance and cash balance from SnapTrade data
      total_balance = calculate_total_balance
      cash_balance = calculate_cash_balance

      Rails.logger.info "SnaptradeAccount::Processor - Balance update: total=#{total_balance}, cash=#{cash_balance}"

      # Update the cached fields on the account
      account.assign_attributes(
        balance: total_balance,
        cash_balance: cash_balance,
        currency: snaptrade_account.currency || account.currency
      )
      account.save!

      # Create or update the current balance anchor valuation for linked accounts
      # This is critical for reverse sync to work correctly
      account.set_current_balance(total_balance)
    end

    def calculate_total_balance
      if use_api_total_balance?
        Rails.logger.debug "SnaptradeAccount::Processor - Using API total for multi-currency holdings for snaptrade_account=#{snaptrade_account.id}"
        return snaptrade_account.current_balance || 0
      end

      holdings_value = calculate_holdings_value
      cash_value = snaptrade_account.cash_balance || 0
      api_total = snaptrade_account.current_balance

      # Trust the brokerage-reported total whenever it accounts for at least
      # the holdings' value. Some brokerages (e.g. Fidelity) report swept
      # cash both as a money-market holding AND in cash_balance, so summing
      # holdings + cash double-counts the cash. The API total is only
      # distrusted when it falls below the holdings value — the known stale
      # case where it reflects just the cash portion.
      if api_total.present? && api_total >= holdings_value * BigDecimal("0.98")
        Rails.logger.info "SnaptradeAccount::Processor - Using API total: #{api_total} (holdings=#{holdings_value}, cash=#{cash_value})"
        api_total
      else
        calculated_total = holdings_value + cash_value
        Rails.logger.info "SnaptradeAccount::Processor - Using calculated total: holdings=#{holdings_value} + cash=#{cash_value} = #{calculated_total} (api_total=#{api_total.inspect})"
        calculated_total
      end
    end

    def calculate_cash_balance
      # Use SnapTrade's cash_balance directly
      # Note: Can be negative for margin accounts
      cash = snaptrade_account.cash_balance
      Rails.logger.info "SnaptradeAccount::Processor - Cash balance from API: #{cash.inspect}"
      cash || BigDecimal("0")
    end

    def calculate_holdings_value
      holdings_data = snaptrade_account.raw_holdings_payload || []
      return 0 if holdings_data.empty?

      holdings_data.sum do |holding|
        data = holding.is_a?(Hash) ? holding.with_indifferent_access : {}
        units = parse_decimal(data[:units]) || 0
        price = parse_decimal(data[:price]) || 0
        units * price
      end
    end

    def use_api_total_balance?
      return false unless snaptrade_account.current_balance.present?

      holdings_currencies.any? { |currency| currency.present? && currency != snaptrade_account.currency }
    end

    def holdings_currencies
      Array(snaptrade_account.raw_holdings_payload).filter_map do |holding|
        data = holding.respond_to?(:with_indifferent_access) ? holding.with_indifferent_access : {}
        extract_currency(data, extract_symbol_data(data), snaptrade_account.currency)
      end.uniq
    end

    def extract_symbol_data(data)
      symbol_wrapper = data[:symbol].is_a?(Hash) ? data[:symbol].with_indifferent_access : {}
      raw_symbol_data = symbol_wrapper[:symbol]

      raw_symbol_data.is_a?(Hash) ? raw_symbol_data.with_indifferent_access : {}
    end
end
