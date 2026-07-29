class Family::SyncCompleteEvent
  attr_reader :family

  def initialize(family)
    @family = family
  end

  def broadcast
    # Replace the #sync-toast slot with a lightweight toast instead of a full
    # page refresh.  The sync-toast Stimulus controller handles three cases:
    #   - User is idle         → morph-refreshes after a short delay
    #   - User is mid-form     → toast stays visible; user clicks "Refresh"
    #   - A modal is open      → toast defers until the dialog closes
    #
    # This avoids wiping in-progress form state when a background sync fires.
    # The partial contains no user-scoped data (Current.user is nil here), so
    # each browser re-fetches the page on its own authenticated request.
    #
    # Failure branch (SIMPLIFICATION_PLAN 2b): this event doesn't know which
    # sync finalized (item events funnel here argument-free), so we probe for
    # a fresh failure in the family tree. Previously failures broadcast the
    # success-worded toast. Window kept short so a successful re-sync minutes
    # later goes back to the success toast; repeat-failure spam is capped
    # client-side (once per day, sync_toast_controller.js).
    failed = Sync.for_family(family).failed.where("syncs.failed_at > ?", 2.minutes.ago).exists?

    family.broadcast_replace_to(
      family,
      target: "sync-toast",
      partial: "shared/notifications/sync_toast",
      locals: { failed: failed }
    )

    # Schedule recurring transaction pattern identification (debounced to run after all syncs complete)
    begin
      RecurringTransaction.identify_patterns_for(family)
    rescue => e
      Rails.logger.error("Family::SyncCompleteEvent recurring transaction identification failed: #{e.message}\n#{e.backtrace&.join("\n")}")
    end
  end
end
