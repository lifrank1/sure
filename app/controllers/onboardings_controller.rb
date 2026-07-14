class OnboardingsController < ApplicationController
  layout "wizard"

  before_action :set_user
  before_action :load_invitation

  # Dashboard section orders unlocked by the onboarding goal question.
  # Keys must match PagesController#build_dashboard_sections keys exactly.
  # "see_everything" deliberately maps to nil: the default order stays the
  # default unless the user expressed a leaning.
  GOAL_SECTION_ORDERS = {
    "overspending"   => %w[spending_pace outflows_donut transactions_to_review net_worth_chart upcoming_recurrings investment_summary],
    "grow_wealth"    => %w[net_worth_chart spending_pace investment_summary outflows_donut transactions_to_review upcoming_recurrings],
    "see_everything" => nil
  }.freeze

  def show
  end

  def preferences
  end

  def connect
  end

  def trial
  end

  # Saves the personalize step (age band + metro -> compare cohort, goal ->
  # dashboard order) and marks onboarding complete server-side — unlike the
  # upstream wizard, completion is not a client-asserted hidden field.
  # Skipping still completes onboarding; the getting-started checklist
  # backstops everything skipped.
  def personalize
    save_personalization unless params[:skip].present?

    Current.user.update!(onboarded_at: Time.current) unless Current.user.onboarded?
    redirect_to connect_onboarding_path
  end

  private
    def set_user
      @user = Current.user
    end

    def load_invitation
      @invitation = Current.family.invitations.accepted.find_by(email: Current.user.email)
    end

    def save_personalization
      # A crafted scalar ?onboarding=x would make params.dig raise; treat
      # anything non-hash-like as an empty answer set.
      answers = params[:onboarding]
      answers = ActionController::Parameters.new unless answers.respond_to?(:dig)

      prefs = {}

      compare = {}
      age = answers[:age_band]
      metro = answers[:metro]
      compare["age_band"] = age if Cohort::AGE_BANDS.include?(age)
      if metro.present?
        # Same semantics as ComparisonsController#update_cohort: real metros
        # stored by label, "__national__" stored as nil. metro_answered
        # distinguishes an explicit national choice from never-asked so the
        # /compare capture form stops re-prompting.
        compare["metro"] = Cohort::METROS.key?(metro) ? metro : nil
        compare["metro_answered"] = true
      end
      prefs["compare"] = compare if compare.any?

      goal = answers[:goal]
      if GOAL_SECTION_ORDERS.key?(goal)
        prefs["onboarding_goal"] = goal
        order = GOAL_SECTION_ORDERS[goal]
        prefs["section_order"] = order if order
      end

      Current.user.update_dashboard_preferences(prefs) if prefs.any?
    end
end
