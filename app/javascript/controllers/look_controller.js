import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="look"
//
// Owns the three look axes (palette / typeface / style) on <html>.
//
// Why a controller at all when the layout already renders the attributes:
// Turbo Drive replaces <body> and merges <head>, but never re-renders <html>.
// After the Appearance form saves and redirects, the server-rendered
// attributes are stale for the life of the tab — so an in-body element carries
// the current values and writes them onto documentElement whenever it
// connects. Same two-instance pattern the existing theme controller uses.
//
// It also powers try-before-you-save: the pickers set values here directly, so
// the whole app re-skins instantly, and the form persists in the background.
export default class extends Controller {
  static values = {
    palette: String,
    typeface: String,
    style: String,
  };

  static ATTRS = {
    palette: "data-palette",
    typeface: "data-typeface",
    style: "data-ui-style",
  };

  connect() {
    // A Turbo restore visit (back/forward) replays a CACHED body, whose values
    // are whatever the look was when that snapshot was taken — applying them
    // blindly reverts a look the user changed since. localStorage holds the
    // newest choice (written on every apply, including saves, which re-render
    // with fresh server values), so it wins. Same shape as theme_controller's
    // localStorage.theme.
    const stored = this.#readStored();
    Object.keys(this.constructor.ATTRS).forEach((axis) => {
      if (stored[axis]) this[`${axis}Value`] = stored[axis];
    });
    this.#applyAll();
  }

  paletteValueChanged() {
    this.#apply("palette");
  }

  typefaceValueChanged() {
    this.#apply("typeface");
  }

  styleValueChanged() {
    this.#apply("style");
  }

  // Bound to the pickers: data-action="look#preview" with
  // data-axis="palette" data-value="sequoia" on the input/label.
  preview(event) {
    const el = event.currentTarget;
    const axis = el.dataset.axis || el.closest("[data-axis]")?.dataset.axis;
    const value = el.dataset.value ?? el.value;
    if (!axis || !value || !(axis in this.constructor.ATTRS)) return;
    this[`${axis}Value`] = value;
  }

  #readStored() {
    try {
      return JSON.parse(localStorage.getItem("look") || "{}");
    } catch {
      return {};
    }
  }

  #store(axis, value) {
    try {
      localStorage.setItem(
        "look",
        JSON.stringify({ ...this.#readStored(), [axis]: value }),
      );
    } catch {
      // Storage unavailable — the server-rendered attributes still apply.
    }
  }

  #apply(axis) {
    const value = this[`${axis}Value`];
    if (!value) return;
    document.documentElement.setAttribute(this.constructor.ATTRS[axis], value);
    this.#store(axis, value);
    // Charts read tokens at render time; tell them to re-read (the existing
    // theme:change consumers already listen for exactly this).
    document.documentElement.dispatchEvent(
      new CustomEvent("theme:change", {
        detail: { axis, value, theme: document.documentElement.dataset.theme },
      }),
    );
  }

  #applyAll() {
    Object.keys(this.constructor.ATTRS).forEach((axis) => this.#apply(axis));
  }
}
