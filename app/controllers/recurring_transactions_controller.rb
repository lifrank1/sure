class RecurringTransactionsController < ApplicationController
  # The standalone page is gone (SIMPLIFICATION_PLAN 1c) — management
  # lives on the Transactions "Upcoming" tab now.
  def index
    redirect_to transactions_path(tab: "upcoming"), status: :moved_permanently
  end

  def update_settings
    Current.family.update!(recurring_settings_params)

    respond_to do |format|
      format.html do
        flash[:notice] = t("recurring_transactions.settings_updated")
        redirect_back_or_to transactions_path(tab: "upcoming")
      end
    end
  end

  def identify
    count = RecurringTransaction.identify_patterns_for!(Current.family)

    respond_to do |format|
      format.html do
        flash[:notice] = t("recurring_transactions.identified", count: count)
        redirect_to transactions_path(tab: "upcoming")
      end
    end
  end

  def cleanup
    count = RecurringTransaction.cleanup_stale_for(Current.family)

    respond_to do |format|
      format.html do
        flash[:notice] = t("recurring_transactions.cleaned_up", count: count)
        redirect_to transactions_path(tab: "upcoming")
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
        redirect_to transactions_path(tab: "upcoming")
      end
    end
  end

  def destroy
    @recurring_transaction = Current.family.recurring_transactions.accessible_by(Current.user).find(params[:id])
    @recurring_transaction.destroy!

    flash[:notice] = t("recurring_transactions.deleted")
    redirect_to transactions_path(tab: "upcoming")
  end

  private

    def recurring_settings_params
      { recurring_transactions_disabled: params[:recurring_transactions_disabled] == "true" }
    end
end
