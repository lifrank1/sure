# Frank Finance — UX Roadmap

> Source of truth for product/UX work on the hosted instance (finance.erech.app).
> Update checkboxes as items land. Context and rationale: see [CONTEXT.md](CONTEXT.md).
> Benchmark: Copilot Money (audited 2026-07-05 side-by-side with real data).

## Phase 1 — Stop the bleeding (quick wins)

- [x] **P1.1 Collapse/hide the AI chat sidebar by default.** Every page reserves ~25%
      width for a right panel that currently shows an eternal spinner (chat is broken
      with Gemini tool-calls — separate bug). Reclaim the space; users opt in.
- [x] **P1.2 Expand account groups by default** in the left accounts panel so
      balances are visible without clicks (Copilot pattern).
- [x] **P1.3 Fix the cashflow story.** Sankey/dashboard/reports are swamped by
      brokerage noise: "Uncategorized $49k" and "Investment Contributions $113k"
      dwarf real spending. Exclude investment-account cash journaling from
      spending analytics; keep true external contributions visible but secondary.
- [x] **P1.4 Non-sticky transaction filters.** Filters persist across sessions
      invisibly (user saw "Expenses $0.00" due to a stale Income chip). Either stop
      persisting or make the filtered state loud with one-click clear.

## Phase 2 — The review loop (Copilot's killer pattern)

- [x] **P2.1 Transaction detail panel.** Existing right-side drawer kept (already
      master-detail-ish); gained a review-confirm banner. Merchant history in the
      drawer: still TODO (moved to Later).
- [x] **P2.2 "Needs review" flag** on newly synced transactions + one-click confirm.
- [x] **P2.3 Dashboard "Transactions to review" card** feeding the loop.

## Phase 3 — Dashboard as actionable card grid

- [x] **P3.1 Card grid dashboard**: Monthly spending ("$X left"), Net worth,
      Review queue, Top categories vs budget, Next-two-weeks recurrings.
- [x] **P3.2 Move the sankey into Reports** (keep it for the curious; stop leading
      with it).
- [x] **P3.3 Surface Recurrings** in nav (feature exists at /recurring_transactions,
      just not linked).

## Later / opportunistic

- [ ] Merge icon nav rail + accounts panel into one sidebar (bigger app-shell refactor)
- [ ] Account sparklines + "last synced X ago" freshness in sidebar
- [ ] Categories page unifying budget + category management (Copilot-style)
- [ ] Recurring page opens inside the settings shell (Back/ESC chrome) — give it a standalone layout
- [ ] Merchant history section in the transaction drawer
- [ ] Fix AI chat with Gemini (400 on tool-call round-trip; suspect tool_calls
      message format vs Gemini OpenAI-compat endpoint)

## Done (this initiative)

- [x] Header icon controls labeled (Accounts / Hide amounts / AI chat); dashboard
      button renamed "Add account"
- [x] Outflows section compacted (smaller donut, scrolling category list) and
      shows its period inline (answers "is this all time?")
- [x] Review-card + new-card padding/alignment normalized (px-4 convention)

- [x] Connect-first add-account flow (bank/brokerage/manual)
- [x] SnapTrade auto-link (no "accounts need setup" step)
- [x] SnapTrade cash double-count fix (Fidelity SPAXX sweep)
- [x] Accounts sidebar: removed All/Assets/Debts tabs; grouped list
- [x] Data-provider warning gated to super_admin; Yahoo Finance keyless providers
- [x] Provider whitelist (ENABLED_PROVIDERS); default auto-categorize rule at signup
- [x] Skip onboarding flow at signup; rebrand; legal pages; /contact page
