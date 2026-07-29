import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="sync-toast"
//
// Shown when a background sync completes and the family's data has changed.
// - Idle              → morph-refreshes the page after a short delay.
// - Mid-form          → stays put; the user refreshes when ready.
// - A modal <dialog> is open → the toast is deferred (it would otherwise sit
//   dimmed-but-clickable behind the dialog's top-layer backdrop, and a refresh
//   would close the dialog and discard its in-progress input). It is revealed
//   once the dialog closes — the first moment a refresh is actually safe.
export default class extends Controller {
  static values = {
    autoRefreshDelay: { type: Number, default: 2000 },
    failed: { type: Boolean, default: false },
  };

  connect() {
    if (this.failedValue) {
      this.#connectFailed();
      return;
    }
    if (this.#dialogOpen()) {
      this.#deferUntilDialogCloses();
      return;
    }
    this.#arm();
  }

  // Failure variant: informational, never auto-refreshes (a morph would wipe
  // the message moments later), capped at roughly once per day — a dead
  // connection fails again on every nightly/login sync, and repeating the
  // same warning daily is the dashboard banner's job, not the toast's.
  #connectFailed() {
    // The first-sync waiting card promises "the page will refresh on its
    // own", and a FAILED first sync is otherwise the one path that never
    // re-renders it. Morph so the card resolves to its check-connections
    // variant (plus the connection banner) instead of spinning forever.
    if (document.getElementById("first-sync-waiting")) {
      this.refresh();
      return;
    }
    if (this.#failureSuppressed()) {
      // Hide, never remove: this element IS the #sync-toast broadcast slot.
      // Removing it makes every later broadcast_replace_to a silent no-op —
      // including the success toast whose morph-refresh other UI relies on.
      this.element.style.display = "none";
      return;
    }
    if (this.#dialogOpen()) {
      this.#deferUntilDialogCloses();
      return;
    }
    this.#markFailureShown();
  }

  // Close button for both variants. Hides rather than removes so the
  // #sync-toast broadcast slot survives for the rest of the page session.
  dismiss() {
    clearTimeout(this._timer);
    this.element.style.display = "none";
  }

  disconnect() {
    clearTimeout(this._timer);
    this.#removeDeferredDialogListener();
  }

  // Turbo 8 morph refresh (the app sets `turbo_refreshes_with method: :morph,
  // scroll: :preserve`) instead of window.location.reload(): no white flash,
  // scroll position and `data-turbo-permanent` elements (the AI chat panel)
  // are preserved.
  refresh() {
    clearTimeout(this._timer);
    Turbo.visit(window.location.href, { action: "replace" });
  }

  #arm() {
    if (this.#userIsInteracting()) return; // mid-form: wait for a manual refresh
    // Re-check at fire time, not just arm time: the post-dialog reveal often
    // lands on a form the dialog was sitting on, and the user resumes typing
    // inside this window (a morph would wipe their non-turbo-permanent
    // input). A dialog opened during the window is the same hazard — the
    // refresh would close it. Either way, bail and leave the toast visible
    // for a manual refresh, matching the mid-form behavior.
    this._timer = setTimeout(() => {
      if (this.#userIsInteracting() || this.#dialogOpen()) return;
      this.refresh();
    }, this.autoRefreshDelayValue);
  }

  #deferUntilDialogCloses() {
    this.element.style.display = "none";
    const dialog = document.querySelector("dialog[open]");
    if (!dialog) {
      this.#reveal();
      return;
    }
    // Keep refs so disconnect() can detach this listener. Otherwise a toast
    // replaced by a newer broadcast while the dialog is still open stays
    // subscribed, and its now-detached controller fires #reveal()/#arm() on
    // close — a spurious auto-refresh from a stale toast.
    //
    // Known edge: if this dialog leaves the DOM without firing `close` (e.g.
    // a morph removes it), the toast stays hidden until the next broadcast
    // replaces it. Acceptable: the next sync re-delivers the toast.
    this._deferredDialog = dialog;
    this._dialogCloseHandler = () => this.#onDialogClose();
    dialog.addEventListener("close", this._dialogCloseHandler, { once: true });
  }

  #onDialogClose() {
    // The `once` listener has already fired and detached itself.
    this._deferredDialog = null;
    this._dialogCloseHandler = null;
    // Another dialog may still be open (stacked modals) — keep deferring until
    // every dialog has closed.
    if (this.#dialogOpen()) {
      this.#deferUntilDialogCloses();
      return;
    }
    this.#reveal();
  }

  #removeDeferredDialogListener() {
    if (this._deferredDialog && this._dialogCloseHandler) {
      this._deferredDialog.removeEventListener(
        "close",
        this._dialogCloseHandler,
      );
    }
    this._deferredDialog = null;
    this._dialogCloseHandler = null;
  }

  #reveal() {
    this.element.style.display = "";
    if (this.failedValue) {
      // Mark at the moment the toast is actually seen (a deferred toast may
      // never be revealed if it's replaced first) — and never auto-refresh.
      this.#markFailureShown();
      return;
    }
    this.#arm();
  }

  #dialogOpen() {
    return !!document.querySelector("dialog[open]");
  }

  // A single failing sync cycle broadcasts the toast several times within
  // seconds (each finalizing item re-broadcasts through the family event), so
  // the once-per-day cap uses a timestamp with a grace window: replacements
  // inside the window re-show (same cycle), repeats hours later are
  // suppressed. Without this, leg #2 of the first cycle would see "already
  // shown today" and the warning would flash for milliseconds and vanish.
  static FAILURE_GRACE_MS = 10 * 60 * 1000;

  // localStorage over sessionStorage so the cap holds across tabs; guarded
  // because storage access can throw (private mode, disabled storage).
  #failureSuppressed() {
    try {
      const ts = Number(localStorage.getItem("syncFailureToastShownAt"));
      if (!ts) return false;
      const sameDay =
        new Date(ts).toDateString() === new Date().toDateString();
      const withinGrace =
        Date.now() - ts < this.constructor.FAILURE_GRACE_MS;
      return sameDay && !withinGrace;
    } catch {
      return false;
    }
  }

  #markFailureShown() {
    try {
      localStorage.setItem("syncFailureToastShownAt", String(Date.now()));
    } catch {
      // Storage unavailable — worst case the toast repeats.
    }
  }

  #userIsInteracting() {
    const el = document.activeElement;
    if (!el || el === document.body || el === document.documentElement)
      return false;
    return (
      el.isContentEditable ||
      el.closest("form, dialog, [role='dialog']") !== null
    );
  }
}
