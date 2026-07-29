import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="poll-refresh"
//
// Morph-refreshes the page after an interval, for transient states that must
// eventually resolve server-side even when no broadcast arrives (a wedged
// first sync, a lost stream connection). Each refresh re-renders the state;
// if it's still transient the controller reconnects and schedules the next
// tick, so this polls only for as long as the transient markup exists.
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 60000 },
  };

  connect() {
    this._timer = setTimeout(() => {
      Turbo.visit(window.location.href, { action: "replace" });
    }, this.intervalValue);
  }

  disconnect() {
    clearTimeout(this._timer);
  }
}
