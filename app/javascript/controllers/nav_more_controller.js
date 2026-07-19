import { Controller } from "@hotwired/stimulus";

// Remembers whether the sidebar "More" group is expanded. Client-side
// persistence (localStorage) like theme/privacy mode — not worth a server
// round-trip. When the current page lives inside the group the server
// renders it open (forced) and we don't let a stale "closed" pref hide it.
export default class extends Controller {
  static values = { forced: Boolean };

  connect() {
    this.restoring = true;
    if (!this.forcedValue && localStorage.getItem("navMoreOpen") === "true") {
      this.element.open = true;
    }
    this.restoring = false;
  }

  persist() {
    if (this.restoring) return;
    localStorage.setItem("navMoreOpen", this.element.open ? "true" : "false");
  }
}
