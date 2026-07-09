# Fetches public-data benchmarks (US government + Zillow) used by the
# "How you compare" cohort feature. All figures are population statistics —
# never other users' data — so nothing here is privacy-sensitive.
#
# Sources, all verified reachable 2026-07:
#   - BLS Consumer Expenditure Survey (CEX): spending by category × age band. Keyless.
#   - Zillow Observed Rent Index (ZORI): metro rent, monthly. Keyless CSV.
#   - Census ACS: metro median household income + gross rent. Needs CENSUS_API_KEY.
#   - FRED: national personal saving rate. Needs FRED_API_KEY.
#   - Fed SCF: net-worth percentiles by age. Static (triennial) — table below.
#
# Everything is cached aggressively: this data updates monthly-to-triennially,
# so a stale-by-a-day benchmark is fine and we never want to hammer the sources.
class PublicBenchmark
  Error = Class.new(StandardError)

  # CEX "age of reference person" demographic suffixes (verified: LB0402 = under 25).
  CEX_AGE_SUFFIX = {
    "under_25" => "LB0402",
    "25_34"    => "LB0403",
    "35_44"    => "LB0404",
    "45_54"    => "LB0405",
    "55_64"    => "LB0406",
    "65_plus"  => "LB0407"
  }.freeze

  # CEX item codes (verified: FOODTOTL, HOUSING, ENTRTAIN, PENSIONS, INCAFTTX).
  CEX_ITEM = {
    food:          "FOODTOTL",
    housing:       "HOUSING",
    entertainment: "ENTRTAIN",
    pensions:      "PENSIONS",   # personal insurance + pensions (captures 401k)
    income_after_tax: "INCAFTTX"
  }.freeze

  # Fed Survey of Consumer Finances 2022 — net-worth percentile breakpoints by
  # age of head of household (USD). Static reference; refresh when 2025 SCF lands.
  # Source: Federal Reserve SCF 2022 summary tables.
  SCF_NET_WORTH_PERCENTILES = {
    "under_35" => { 25 => 3_500, 50 => 39_000, 75 => 130_000, 90 => 300_000 },
    "35_44"    => { 25 => 30_000, 50 => 135_600, 75 => 375_000, 90 => 850_000 },
    "45_54"    => { 25 => 60_000, 50 => 247_200, 75 => 700_000, 90 => 1_600_000 },
    "55_64"    => { 25 => 90_000, 50 => 364_500, 75 => 1_000_000, 90 => 2_500_000 },
    "65_plus"  => { 25 => 120_000, 50 => 409_900, 75 => 1_100_000, 90 => 2_600_000 }
  }.freeze

  CACHE_TTL = 7.days

  class << self
    # Average annual spend for a CEX category and age band (USD/year), or nil.
    def cex_annual(item:, age_band:)
      suffix = CEX_AGE_SUFFIX[age_band.to_s]
      code = CEX_ITEM[item.to_sym]
      return nil unless suffix && code

      series_id = "CXU#{code}#{suffix}M"
      cached("cex:#{series_id}") do
        data = bls_series(series_id)
        data&.dig(0, "value")&.to_f
      end
    end

    # Latest Zillow observed rent for a metro (USD/month), or nil.
    # NOTE: Zillow keys metros by RegionName (e.g. "New York, NY"), NOT by CBSA
    # code — different identifier than Census below. The Cohort resolver maps a
    # user's location to both a Zillow region name and a Census CBSA code.
    def metro_rent(metro_name:)
      return nil if metro_name.blank?
      zillow_metro_rents[metro_name.to_s]
    end

    # Census ACS median household income for a metro CBSA (USD/year), or nil.
    def metro_income(cbsa:)
      return nil if cbsa.blank? || census_key.blank?
      cached("census:income:#{cbsa}") do
        census_metro(cbsa, "B19013_001E")
      end
    end

    # Current US personal saving rate (percent), or nil.
    def national_savings_rate
      return nil if fred_key.blank?
      cached("fred:psavert") do
        fred_latest("PSAVERT")
      end
    end

    # Percentile (0-100) a given net worth falls at for an age band, or nil.
    def net_worth_percentile(age_band:, net_worth:)
      table = SCF_NET_WORTH_PERCENTILES[age_band.to_s]
      return nil unless table && net_worth

      # Linear interpolation between published breakpoints.
      points = [ [ 0, 0 ] ] + table.map { |pct, val| [ val, pct ] }.sort
      return 0 if net_worth <= points.first[0]
      return 95 if net_worth >= points.last[0]

      points.each_cons(2) do |(v0, p0), (v1, p1)|
        next unless net_worth.between?(v0, v1)
        frac = (net_worth - v0).to_f / (v1 - v0)
        return (p0 + frac * (p1 - p0)).round
      end
      nil
    end

    private
      def cached(key, &block)
        Rails.cache.fetch("public_benchmark:#{key}", expires_in: CACHE_TTL) { block.call }
      rescue => e
        Rails.logger.warn("PublicBenchmark #{key} failed: #{e.message}")
        nil
      end

      def census_key = ENV["CENSUS_API_KEY"].presence
      def fred_key   = ENV["FRED_API_KEY"].presence

      def client
        @client ||= Faraday.new do |f|
          f.request :retry, max: 2
          f.options.timeout = 20
        end
      end

      # BLS public API v1 (keyless): returns the series' data array or nil.
      def bls_series(series_id)
        resp = client.post("https://api.bls.gov/publicAPI/v1/timeseries/data/") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = { seriesid: [ series_id ], startyear: (Date.current.year - 2).to_s, endyear: Date.current.year.to_s }.to_json
        end
        parsed = JSON.parse(resp.body)
        parsed.dig("Results", "series", 0, "data")
      end

      def census_metro(cbsa, var)
        resp = client.get("https://api.census.gov/data/2022/acs/acs5") do |req|
          req.params["get"] = var
          req.params["for"] = "metropolitan statistical area/micropolitan statistical area:#{cbsa}"
          req.params["key"] = census_key
        end
        rows = JSON.parse(resp.body)
        rows[1]&.first&.to_f
      end

      def fred_latest(series_id)
        resp = client.get("https://api.stlouisfed.org/fred/series/observations") do |req|
          req.params["series_id"] = series_id
          req.params["file_type"] = "json"
          req.params["sort_order"] = "desc"
          req.params["limit"] = "1"
          req.params["api_key"] = fred_key
        end
        JSON.parse(resp.body).dig("observations", 0, "value")&.to_f
      end

      # Zillow publishes one wide CSV (metro × month). Fetch + parse the whole
      # thing once and cache the CBSA→latest-rent map for the full TTL.
      def zillow_metro_rents
        Rails.cache.fetch("public_benchmark:zillow:metro_rents", expires_in: CACHE_TTL) do
          url = "https://files.zillowstatic.com/research/public_csvs/zori/Metro_zori_uc_sfrcondomfr_sm_month.csv"
          body = client.get(url).body
          rows = CSV.parse(body, headers: true)
          latest_col = rows.headers.last
          rows.each_with_object({}) do |row, map|
            # RegionType == "msa"; RegionID isn't the CBSA code, but RegionName carries the metro.
            # We key by CBSA via a name→CBSA lookup at the call site; here key by RegionName too.
            val = row[latest_col]
            map[row["RegionName"]] = val.to_f.round if val.present?
          end
        end
      rescue => e
        Rails.logger.warn("PublicBenchmark zillow failed: #{e.message}")
        {}
      end
  end
end
