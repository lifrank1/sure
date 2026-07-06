class RecurringTransactionsController < ApplicationController
  def index
    @recurring_transactions = Current.family.recurring_transactions
                                    .accessible_by(Current.user)
                                    .includes(:merchant)
                                    .order(status: :asc, next_expected_date: :asc)
    @family = Current.family

    # Headline stats: expected monthly outflow across active recurring charges
    # (expenses only — recurring income/transfers don't belong in "you spend
    # $X/month on subscriptions"), plus this month's paid vs still-to-pay
    active_charges = @recurring_transactions.select { |rt| rt.active? && !rt.transfer? && rt.amount.positive? }
    @monthly_recurring_total = Money.new(active_charges.sum(&:amount), Current.family.currency)
    @monthly_recurring_count = active_charges.size

    month_start = Date.current.beginning_of_month
    month_end = Date.current.end_of_month
    paid = active_charges.select { |rt| rt.last_occurrence_date.present? && rt.last_occurrence_date >= month_start }
    due = active_charges.select { |rt| rt.next_expected_date.present? && rt.next_expected_date <= month_end }
    @paid_so_far = Money.new(paid.sum(&:amount), Current.family.currency)
    @left_to_pay = Money.new(due.sum(&:amount), Current.family.currency)

    @breadcrumbs = [ [ t("breadcrumbs.home"), root_path ], [ t("recurring_transactions.title"), nil ] ]
  end

  def update_settings
    Current.family.update!(recurring_settings_params)

    respond_to do |format|
      format.html do
        flash[:notice] = t("recurring_transactions.settings_updated")
        redirect_to recurring_transactions_path
      end
    end
  end

  def identify
    count = RecurringTransaction.identify_patterns_for!(Current.family)

    respond_to do |format|
      format.html do
        flash[:notice] = t("recurring_transactions.identified", count: count)
        redirect_to recurring_transactions_path
      end
    end
  end

  def cleanup
    count = RecurringTransaction.cleanup_stale_for(Current.family)

    respond_to do |format|
      format.html do
        flash[:notice] = t("recurring_transactions.cleaned_up", count: count)
        redirect_to recurring_transactions_path
      end
    end
  end

  def toggle_status
    @recurring_transaction = Current.family.recurring_transactions.accessible_by(Current.user).find(params[:id])

    if @recurring_transaction.active?
      @recurring_transaction.mark_inactive!
      message = t("recurring_transactions.marked_inactive")
    else
      @recurring_transaction.mark_active!
      message = t("recurring_transactions.marked_active")
    end

    respond_to do |format|
      format.html do
        flash[:notice] = message
        redirect_to recurring_transactions_path
      end
    end
  end

  def destroy
    @recurring_transaction = Current.family.recurring_transactions.accessible_by(Current.user).find(params[:id])
    @recurring_transaction.destroy!

    flash[:notice] = t("recurring_transactions.deleted")
    redirect_to recurring_transactions_path
  end

  private

    def recurring_settings_params
      { recurring_transactions_disabled: params[:recurring_transactions_disabled] == "true" }
    end
end
