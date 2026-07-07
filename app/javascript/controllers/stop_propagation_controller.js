import { Controller } from "@hotwired/stimulus";

// CSP-safe replacement for inline onclick="event.stopPropagation()".
// Usage: data-controller="stop-propagation" data-action="click->stop-propagation#stop"
export default class extends Controller {
  stop(event) {
    event.stopPropagation();
  }
}
