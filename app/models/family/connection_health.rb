# Answers the dashboard's "is my data trustworthy right now?" questions in one
# place (SIMPLIFICATION_PLAN 2a/2b): is a first sync still materializing
# accounts, is a bank connection dead, has provider data gone stale.
#
# Predicates are built on the VISIBLE (5-minute) sync window, not the raw
# incomplete scope — a crashed Sidekiq job leaves its Sync row pending until
# the 24h cleaner, and an uncapped predicate would trap users in a waiting
# state that long.
class Family::ConnectionHealth
  # Provider data older than this is flagged. Matches SimpleFin's existing
  # >3-day health heuristic (simplefin_item.rb) so the dashboard and the
  # settings health strip don't disagree about who is stale.
  STALE_AFTER = 3.days

  attr_reader :family

  def initialize(family)
    @family = family
  end

  # Any pending/syncing Sync anywhere in the family tree — family, accounts,
  # or provider items. Family#syncing? misses first provider syncs entirely
  # (they run on the item, never the family), which is why this exists.
  def syncing?
    return @syncing if defined?(@syncing)
    @syncing = Sync.for_family(family).visible.exists?
  end

  # Live provider connections (bank links etc.), excluding ones the user has
  # already removed.
  def provider_items
    @provider_items ||= ProviderConnectionStatus::PROVIDERS.flat_map do |provider|
      family.public_send(provider[:association]).active.to_a
    end
  end

  # Existence probe kept separate from provider_items: LIMIT-1 queries that
  # short-circuit on the first hit, instead of materializing full item rows
  # (credentials included) on every dashboard render.
  def provider_items?
    return @provider_items_exist if defined?(@provider_items_exist)
    @provider_items_exist =
      if defined?(@provider_items)
        @provider_items.any?
      else
        ProviderConnectionStatus::PROVIDERS.any? do |provider|
          family.public_send(provider[:association]).active.exists?
        end
      end
  end

  # Connections whose credentials no longer work (bank marked them
  # requires_update). These need the user to reconnect — no sync will fix them.
  def dead_items
    @dead_items ||= provider_items? ? provider_items.select(&:requires_update?) : []
  end

  # First-run window: a connection is linked but its sync hasn't materialized
  # any accounts yet. Accounts are created mid-sync, so this is the state
  # right after a Plaid/SnapTrade link succeeds. Account check first: in the
  # common case (accounts exist) it reuses the request-memoized probe and the
  # provider queries never run.
  def awaiting_first_sync?
    return false if family.any_visible_accounts?

    provider_items?
  end

  # Most recent completed sync across provider items only. Deliberately NOT
  # family.latest_sync_completed_at: the nightly family sync completes its
  # manual-account children even when every bank connection fails, keeping
  # that column fresh while provider data rots.
  def latest_provider_sync_completed_at
    return @latest_provider_sync_completed_at if defined?(@latest_provider_sync_completed_at)

    scope = provider_items.group_by { |item| item.class.name }.reduce(nil) do |acc, (type, items)|
      q = Sync.where(syncable_type: type, syncable_id: items.map(&:id))
      acc ? acc.or(q) : q
    end

    @latest_provider_sync_completed_at = scope&.completed&.maximum(:completed_at)
  end

  # When the data went stale: the last completed provider sync, or — for a
  # connection that has NEVER completed one (first sync failing since day
  # one) — when the connection was linked. Without the fallback such a
  # connection is invisible to every dashboard surface in a family that
  # already has accounts.
  def stale_since
    return @stale_since if defined?(@stale_since)
    @stale_since = latest_provider_sync_completed_at || provider_items.map(&:created_at).min
  end

  # Provider data hasn't refreshed in STALE_AFTER and nothing is running.
  # False for manual-only families (manual data cannot go stale) and while a
  # first sync is still visible (that's the waiting state, not staleness).
  def stale?
    return false unless provider_items?
    return false if syncing?

    stale_since.present? && stale_since < STALE_AFTER.ago
  end

  def needs_attention?
    dead_items.any? || stale?
  end
end
