# "How you compare" — benchmarks the user against public-data cohorts
# (never other users). See Cohort, PublicBenchmark, SavingsRate.
class ComparisonsController < ApplicationController
  # One card's view model. `direction` is semantic (relative to what's GOOD for
  # that metric), computed here so the partial never reasons about polarity.
  Card = Data.define(
    :key, :icon, :title, :your_label, :cohort_label,
    :direction, :viz, :your_frac, :cohort_frac, :ring_percent,
    :framing, :source, :method_note, :cta_path, :cta_label
  )

  def show
    @cohort = Cohort.for(Current.user)
    @has_accounts = Current.family.accounts.visible.any?
    @needs_age = !@cohort.age_band?
    @needs_metro = !@cohort.metro?

    @cards = @has_accounts ? build_cards : []

    @breadcrumbs = [ [ t("breadcrumbs.home"), root_path ], [ t("comparisons.title"), nil ] ]
  end

  # Inline age/metro capture → stores under preferences["compare"].
  def update_cohort
    age = params.dig(:compare, :age_band)
    metro = params.dig(:compare, :metro)
    compare = (Current.user.preferences&.dig("compare") || {}).dup
    compare["age_band"] = age if age.present? && Cohort::AGE_BANDS.include?(age)
    compare["metro"] = metro if metro.present?
    compare["metro"] = nil if params.dig(:compare, :metro) == "__national__"
    Current.user.update_dashboard_preferences({ "compare" => compare })
    redirect_to comparisons_path, notice: t("comparisons.cohort_saved")
  end

  private
    def build_cards
      [ savings_card, food_card, subscriptions_card, rent_card, net_worth_card ].compact
    end

    def money(amount) = Money.new(amount, Current.family.currency)

    # ---- Savings rate (lead card; higher is better) ----
    def savings_card
      result = SavingsRate.new(Current.family, user: Current.user).call
      national = PublicBenchmark.national_savings_rate # ~3.0
      cohort_typical = 10 # CEX under-25 retirement contrib ~10% of after-tax income

      unless result.computable?
        return Card.new(
          key: :savings_rate, icon: "piggy-bank", title: t("comparisons.cards.savings.title"),
          your_label: nil, cohort_label: "#{cohort_typical}%", direction: :unknown, viz: :range,
          your_frac: nil, cohort_frac: cohort_typical / 20.0, ring_percent: nil,
          framing: t("comparisons.cards.savings.no_income"),
          source: t("comparisons.sources.fred_cex"), method_note: t("comparisons.cards.savings.method"),
          cta_path: new_account_path(step: "method_select"), cta_label: t("comparisons.cta.link_account")
        )
      end

      pct = result.percent
      direction = if pct >= cohort_typical + 1 then :better
      elsif pct >= cohort_typical - 2 then :on_par
      else :worse end

      framing = case direction
      when :better then t("comparisons.cards.savings.better", national: national&.round || 3)
      when :on_par then t("comparisons.cards.savings.on_par")
      else t("comparisons.cards.savings.worse")
      end
      framing = "#{framing} #{t('comparisons.cards.savings.take_home_note')}" if result.take_home_only

      Card.new(
        key: :savings_rate, icon: "piggy-bank", title: t("comparisons.cards.savings.title"),
        your_label: "#{pct}%", cohort_label: "#{cohort_typical}%", direction: direction, viz: :range,
        your_frac: (pct / 20.0).clamp(0, 1), cohort_frac: cohort_typical / 20.0, ring_percent: nil,
        framing: framing, source: t("comparisons.sources.fred_cex"),
        method_note: t("comparisons.cards.savings.method"),
        cta_path: (result.take_home_only ? new_account_path(step: "method_select") : nil),
        cta_label: (result.take_home_only ? t("comparisons.cta.link_retirement") : nil)
      )
    end

    # ---- Category spend cards (lower is better) ----
    def spend_card(key:, icon:, item:, budget_cta:)
      cohort_annual = PublicBenchmark.cex_annual(item: item, age_band: @cohort.age_band || "under_25")
      return nil unless cohort_annual

      months = 1
      your_monthly = Current.family.income_statement(user: Current.user)
        .expense_totals(period: Period.last_30_days)
        .category_totals.select { |ct| ct.category.name.to_s.downcase.include?(t("comparisons.cards.#{key}.match").downcase) }
        .sum { |ct| ct.total.to_f } / months
      cohort_monthly = cohort_annual / 12.0

      your_label = helpers.format_money(money(your_monthly)) + t("comparisons.per_mo")
      cohort_label = helpers.format_money(money(cohort_monthly)) + t("comparisons.per_mo")

      direction = if your_monthly <= cohort_monthly * 0.9 then :better
      elsif your_monthly <= cohort_monthly * 1.1 then :on_par
      else :worse end

      band = cohort_monthly * 1.6
      framing = t("comparisons.cards.#{key}.#{direction}")

      Card.new(
        key: key, icon: icon, title: t("comparisons.cards.#{key}.title"),
        your_label: your_label, cohort_label: cohort_label, direction: direction, viz: :range,
        your_frac: (your_monthly / band).clamp(0, 1), cohort_frac: (cohort_monthly / band).clamp(0, 1),
        ring_percent: nil, framing: framing, source: t("comparisons.sources.cex"),
        method_note: t("comparisons.cards.#{key}.method", cohort: @cohort.age_label || "under-25"),
        cta_path: (direction == :worse ? budgets_path : nil),
        cta_label: (direction == :worse ? t("comparisons.cta.set_budget") : nil)
      )
    end

    def food_card = spend_card(key: :food, icon: "utensils", item: :food, budget_cta: true)
    def subscriptions_card = spend_card(key: :subscriptions, icon: "credit-card", item: :entertainment, budget_cta: true)

    # ---- Rent-to-income (lower share is better; metro-specific) ----
    def rent_card
      rent = @cohort.metro? ? PublicBenchmark.metro_rent(metro_name: @cohort.zillow_region) : nil
      income = @cohort.annual_income
      return nil unless income && income > 0

      # If we can't get the user's actual rent, compare metro-typical share.
      metro_income = @cohort.census_cbsa ? PublicBenchmark.metro_income(cbsa: @cohort.census_cbsa) : nil
      typical_share = (rent && metro_income && metro_income > 0) ? (rent * 12 / metro_income) : nil

      user_monthly_income = income / 12.0
      your_rent = detected_rent_monthly
      your_share = (your_rent && user_monthly_income > 0) ? (your_rent / user_monthly_income) : nil
      return nil if your_share.nil? && typical_share.nil?

      shown_share = your_share || typical_share
      direction = if shown_share < 0.28 then :better
      elsif shown_share <= 0.32 then :on_par
      else :worse end

      Card.new(
        key: :rent, icon: "home", title: t("comparisons.cards.rent.title"),
        your_label: your_share ? "#{(your_share * 100).round}%" : t("comparisons.cards.rent.metro_typical", pct: (typical_share * 100).round),
        cohort_label: typical_share ? "#{(typical_share * 100).round}%" : t("comparisons.thirty_pct_rule"),
        direction: direction, viz: :range,
        your_frac: (shown_share / 0.5).clamp(0, 1), cohort_frac: (0.30 / 0.5),
        ring_percent: nil,
        framing: t("comparisons.cards.rent.#{direction}", metro: @cohort.metro_label || t("comparisons.your_area")),
        source: t("comparisons.sources.zillow_census"),
        method_note: t("comparisons.cards.rent.method"),
        cta_path: nil, cta_label: nil
      )
    end

    # ---- Net worth percentile (softest framing; last) ----
    def net_worth_card
      return nil unless @cohort.age_band?
      nw = Current.family.balance_sheet.net_worth.amount.to_f
      pct = PublicBenchmark.net_worth_percentile(age_band: @cohort.scf_age_band, net_worth: nw)
      return nil unless pct

      direction = if pct >= 60 then :better
      elsif pct >= 40 then :on_par
      else :worse end

      Card.new(
        key: :net_worth, icon: "trending-up", title: t("comparisons.cards.net_worth.title"),
        your_label: t("comparisons.percentile", n: pct), cohort_label: nil,
        direction: direction, viz: :ring, your_frac: nil, cohort_frac: nil, ring_percent: pct,
        framing: t("comparisons.cards.net_worth.#{direction}", age: @cohort.age_label || ""),
        source: t("comparisons.sources.scf"), method_note: t("comparisons.cards.net_worth.method"),
        cta_path: nil, cta_label: nil
      )
    end

    # Best-effort monthly rent from recurring housing transactions.
    def detected_rent_monthly
      @detected_rent_monthly ||= begin
        cat = Current.family.categories.find_by("LOWER(name) IN (?)", [ "rent", "mortgage / rent", "housing" ])
        next nil unless cat
        Current.family.transactions.visible
          .joins(:entry).where(category_id: cat.id)
          .where(entries: { date: Period.last_30_days.date_range })
          .sum("ABS(entries.amount)").to_f.then { |v| v.positive? ? v : nil }
      end
    rescue
      nil
    end
end
