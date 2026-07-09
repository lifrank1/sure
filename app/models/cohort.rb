# A user's comparison cohort for the "How you compare" feature: age band ×
# metro × income. Resolved from what we know (age band + metro live in user
# preferences; income is detected from linked accounts). Degrades gracefully —
# a missing metro just means national benchmarks, never an error.
class Cohort
  AGE_BANDS = %w[under_25 25_34 35_44 45_54 55_64 65_plus].freeze

  # Curated top US metros: user-facing label => [Zillow RegionName, Census CBSA].
  # Zillow keys by "City, ST"; Census by CBSA code. Unlisted cities fall back to
  # the national cohort. Covers the large majority of a US user base; extend as
  # needed.
  METROS = {
    "New York"       => [ "New York, NY", "35620" ],
    "Los Angeles"    => [ "Los Angeles, CA", "31080" ],
    "Chicago"        => [ "Chicago, IL", "16980" ],
    "Dallas"         => [ "Dallas, TX", "19100" ],
    "Houston"        => [ "Houston, TX", "26420" ],
    "Washington DC"  => [ "Washington, DC", "47900" ],
    "Miami"          => [ "Miami, FL", "33100" ],
    "Philadelphia"   => [ "Philadelphia, PA", "37980" ],
    "Atlanta"        => [ "Atlanta, GA", "12060" ],
    "Boston"         => [ "Boston, MA", "14460" ],
    "Phoenix"        => [ "Phoenix, AZ", "38060" ],
    "San Francisco"  => [ "San Francisco, CA", "41860" ],
    "Seattle"        => [ "Seattle, WA", "42660" ],
    "San Diego"      => [ "San Diego, CA", "41740" ],
    "Denver"         => [ "Denver, CO", "19740" ],
    "Austin"         => [ "Austin, TX", "12420" ],
    "Minneapolis"    => [ "Minneapolis, MN", "33460" ],
    "Portland"       => [ "Portland, OR", "38900" ],
    "Nashville"      => [ "Nashville, TN", "34980" ],
    "Charlotte"      => [ "Charlotte, NC", "16740" ]
  }.freeze

  attr_reader :age_band, :metro_label

  def self.for(user)
    prefs = user&.preferences || {}
    new(
      user: user,
      age_band: prefs.dig("compare", "age_band"),
      metro_label: prefs.dig("compare", "metro")
    )
  end

  def initialize(user:, age_band: nil, metro_label: nil)
    @user = user
    @age_band = age_band.presence_in(AGE_BANDS)
    @metro_label = metro_label.presence
  end

  def age_band? = age_band.present?
  def metro? = metro_resolved.present?

  # SCF uses "under_35" for the youngest net-worth band; CEX uses "under_25".
  # Map our stored band to the SCF grouping.
  def scf_age_band
    case age_band
    when "under_25", "25_34" then "under_35"
    else age_band
    end
  end

  def zillow_region = metro_resolved&.first
  def census_cbsa   = metro_resolved&.last

  # Human-readable cohort description for microcopy.
  def description
    age = age_label || "all ages"
    place = metro_label.presence || "the U.S."
    "people #{age} in #{place}"
  end

  def age_label
    { "under_25" => "18–24", "25_34" => "25–34", "35_44" => "35–44",
      "45_54" => "45–54", "55_64" => "55–64", "65_plus" => "65+" }[age_band]
  end

  # Detected take-home income over a trailing window, family currency (annualized).
  def annual_income
    @annual_income ||= begin
      stmt = @user&.family&.income_statement(user: @user)
      return nil unless stmt
      monthly = stmt.income_totals(period: Period.last_30_days).total
      monthly.to_f * 12
    rescue
      nil
    end
  end

  private
    def metro_resolved
      return nil if metro_label.blank?
      METROS[metro_label]
    end
end
