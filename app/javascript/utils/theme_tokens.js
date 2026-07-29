// Resolve design tokens to concrete color strings at draw time.
//
// SVG/canvas drawing can't use `var(--color-x)` everywhere: D3 needs real
// values to do opacity math (d3.color()), and some SVG attributes bake their
// value at draw time. Controllers used to hardcode light/dark hex pairs, which
// meant they ignored the palette axis entirely (a Sequoia or Tokyo Night user
// still got #171717 axis labels).
//
// Values are cached per (token, theme signature) and the cache is dropped
// whenever any look axis changes, so the next draw re-reads the live values.
let cache = new Map();
let signature = "";

function currentSignature() {
  const el = document.documentElement;
  return [
    el.dataset.theme,
    el.dataset.palette,
    el.dataset.uiStyle,
  ].join("|");
}

function ensureFresh() {
  const sig = currentSignature();
  if (sig !== signature) {
    signature = sig;
    cache = new Map();
  }
}

// `token` is the custom property name, with or without the leading dashes:
//   resolveToken("--color-gray-900") | resolveToken("color-gray-900")
// Also accepts a full `var(--x)` string so existing call sites can pass their
// token constants through unchanged.
export function resolveToken(token, fallback = "") {
  if (!token) return fallback;

  const name = token
    .replace(/^var\(\s*/, "")
    .replace(/\s*\)$/, "")
    .trim()
    .replace(/^(?!--)/, "--");

  ensureFresh();
  if (cache.has(name)) return cache.get(name);

  const value = getComputedStyle(document.documentElement)
    .getPropertyValue(name)
    .trim();
  const resolved = value || fallback;
  cache.set(name, resolved);
  return resolved;
}

// True when a string still needs resolving.
export function isTokenRef(value) {
  return typeof value === "string" && value.startsWith("var(--");
}

// Attributes whose change should invalidate cached colors and trigger a
// redraw. Charts observe all of these, not just data-theme.
export const LOOK_ATTRIBUTES = ["data-theme", "data-palette", "data-ui-style"];

// Convenience: observe look changes and run `onChange`. Returns the observer so
// callers can disconnect on Stimulus disconnect().
export function observeLookChanges(onChange) {
  if (typeof MutationObserver === "undefined") return null;

  const observer = new MutationObserver((mutations) => {
    if (mutations.some((m) => LOOK_ATTRIBUTES.includes(m.attributeName))) {
      ensureFresh();
      onChange();
    }
  });
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: LOOK_ATTRIBUTES,
  });
  return observer;
}
