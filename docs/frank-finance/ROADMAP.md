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

## UX audit 2026-07-05 (full walkthrough, live app, desktop) — fixes shipped 2026-07-06

Trust-breaking numbers (data correctness IS the UX in a finance app):

- [x] Holdings table: now aggregated by security across accounts with
      portfolio-wide weights (InvestmentStatement#allocation); merged rows
      show "· N accounts"; return uses summed cost basis (still "-" when no
      account has cost basis — honest unknown, e.g. TG3Y)
- [x] Reports contradictions: Activity Breakdown + CSV export now mirror
      IncomeStatement::Totals scoping exactly (spending accounts only, no
      trades, no transfer-ish activity labels, no tax-advantaged, no pending,
      investment_contribution/loan_payment classify as expense) so tables sum
      to the cards; Investment Performance contributions/withdrawals now come
      from InvestmentFlowStatement (real external flows — a stock sale is not
      a withdrawal); redundant Investment Flows section removed; dashboard
      "All time activity" relabeled Securities bought/sold; Period Return
      only counts a day's market flows when the account held >= 1 unit the
      prior day (a 401k whose holdings dropped to -$0.0027 dust then
      re-materialized at $40k had booked the whole value as a +31% month;
      July MTD is now -$647, verified against prod balances)
- [x] Dashboard Outflows: Investment Contributions split out of the donut into
      a secondary "Moved to investments" line (still linked); card renamed
      "Spending"; percentages recomputed vs spending total

Time-period consistency:

- [x] Outflows card defaults to current month (own picker still there);
      Net Worth chart gained its own period picker (defaults to global);
      transactions summary strip now labeled with its period ("All time" /
      "Since …"). Global sticky period behavior unchanged.

Interaction / click-depth:

- [x] AI chat UI (header toggle, right panel, mobile Assistant tab) gated
      behind AI_CHAT_UI_ENABLED env var — set to false in Railway until the
      Gemini tool-call fix lands. Also fixed for re-enablement: panel opened
      as a ~60px sliver (w-full vs flex-grow battle → now fixed w-[400px]),
      and toggle persistence PATCHed /users/undefined (userId Stimulus value
      was never declared)
- [x] Transactions default 50/page (accounts feed 25)
- [x] Duplicate account names: Account#display_name suffixes Plaid mask
      ("CREDIT CARD ••1234") only when names collide; account filter now
      filters by account_ids (name-based filtering couldn't distinguish the
      four cards at all); applied to sidebar, filters, badges, settings rows,
      account page title, transaction rows
- [x] "Next two weeks" rows link to that charge's transaction history
- [x] Recurring page: monthly total headline ("$X/month across N charges"),
      data first, toggle + detection explainer demoted below, merchant names
      link to transaction history, "Identify Patterns" → "Scan for recurring
      charges". Dunkin' double-detection is a pattern-dedup issue — still open
- [x] Add-account modal: DS::Dialog gained return_on_close — closing a
      full-page dialog now goes back (or to a fallback path) instead of
      stranding on a blank page
- [x] Budget empty states: Reports card shows "No budget set" + create CTA
      (was "0% of budget used"); Budgets page shows an honest empty card
      instead of "ON TRACK · 23" with $0.00 rows

Polish:

- [x] Raw bank strings: Entry#display_name strips PPD/WEB/CCD IDs + 6+-digit
      reference runs and de-shouts ALL CAPS in lists; stored name untouched
      (drawer Name field + rule matching still see the original)
- [x] "Updated Xh ago" freshness on the account page header
- [x] Transaction drawer Overview shows the account (linked, with logo)
- [x] Version string: already super_admin-gated (audit saw it as the admin)
- [ ] Categories settings page: flat chip list, no per-category spend/usage to
      inform pruning (feeds the existing Copilot-style categories-page item)
- [x] "vs. beginning" → "all time"
- [ ] Recurring pattern detection can emit near-duplicates (Dunkin' on day 18
      and day 19) — needs merge/dedup logic or a UI merge affordance

Verified good: review loop end-to-end, Categorize wizard (merchant-grouped,
rule creation, AI auto-label), add-account chooser, filter panel, transfer
auto-match confirm, section collapse/reorder, breadcrumbs + keyboard hints.
NOT verified: mobile layout (browser window wouldn't resize; needs a real
device/emulator pass — student audience makes this the top follow-up),
fresh-signup first-run.

## Copilot Money parity pass (2026-07-06, benchmarked in-app side by side)

Shipped:

- [x] Sidebar nav now Copilot-shaped: Home, Transactions, Accounts,
      Investments, Categories, Recurring, Budgets, Reports (new items are
      desktop-only; mobile bottom nav unchanged)
- [x] New /investments page (InvestmentPortfolioController): portfolio value +
      total/period return, balance chart with period picker
      (Balance::ChartSeriesBuilder over investment accounts), full holdings
      allocation table, account cards with freshness, period activity strip
      (real flows + buys/sells/trades)
- [x] Categories page is now a Copilot-style overview: month header (spent vs
      total budget), per-category rows with spent + progress bar against
      budget (red/amber at 100%/80%) or monthly average when no budget,
      uncategorized CTA row into the wizard; full management list kept in a
      disclosure; standalone layout (was settings shell)
- [x] Recurring: "Paid so far / Left to pay this month" headline stats;
      status column upgraded from Active/Inactive to Paid ✓ / Overdue /
      Due <date> / Paused
- [x] Accounts page standalone (was settings shell) + Assets / Debts /
      Net worth summary strip
- [x] Dashboard card grid now kicks in at xl (1280px) instead of 2xl (1536px)
      and two-column is the default (opt-out in Settings > Appearance)

Deliberately not ported (need real-time quotes the keyless Yahoo provider
can't do): live balance estimate, "top movers today" carousel, per-security
intraday price panel. Copilot's paid-checkmark accuracy also depends on
bill-level matching we approximate with last_occurrence_date.

## Later / opportunistic

- [x] Merge icon nav rail + accounts panel into one sidebar (nav rows with labels,
      brand header, accounts below, contact + user menu footer)
- [ ] Account sparklines + "last synced X ago" freshness in sidebar
- [ ] Categories page unifying budget + category management (Copilot-style)
- [ ] Service worker registration fails (422 on /service-worker) — breaks PWA
      install/offline; likely the route needs skip_authentication
- [ ] Plaid EU shows as an available provider (ENABLED_PROVIDERS=plaid prefix-
      matches plaid_eu) — noise for a US-only user base
- [ ] Account balance chart has no loading state (blank box during first
      hydration on cold cache)
- [x] Recurring page opens inside the settings shell (Back/ESC chrome) — give it a standalone layout
- [ ] Merchant history section in the transaction drawer
- [x] Fix AI chat with Gemini (2026-07-06). Root cause was NOT the immediate
      tool round-trip (a prior session's thought_signature placeholder fixed
      that) — it was history replay: ToolCall::Function#to_tool_call sent the
      stored jsonb arguments as a Hash, and Gemini 400s "Value is not a
      string". Arguments now stringified per OpenAI spec; replayed history
      tool_calls also get the Gemini placeholder signature. Reproduced +
      verified both shapes against the live endpoint. AI_CHAT_UI_ENABLED=true
      restored (UI had been hidden while broken).

## Done (this initiative)

- [x] Header icon controls labeled (Accounts / Hide amounts / AI chat); dashboard
      button renamed "Add account"
- [x] Outflows section compacted (smaller donut, scrolling category list) and
      shows its period inline (answers "is this all time?")
- [x] Review-card + new-card padding/alignment normalized (px-4 convention)
- [x] Default categories trimmed 22 -> 13 for the college-student audience
      (new families only; niche categories addable in Settings > Categories)
- [x] QA sweep 2026-07-05: fixed turbo-frame-timeout race that stamped
      'Timeout' over healthy sparklines on every account; verified drawer,
      wizard, budgets, reports, bank-sync, add-account chooser all clean

- [x] Connect-first add-account flow (bank/brokerage/manual)
- [x] SnapTrade auto-link (no "accounts need setup" step)
- [x] SnapTrade cash double-count fix (Fidelity SPAXX sweep)
- [x] Accounts sidebar: removed All/Assets/Debts tabs; grouped list
- [x] Data-provider warning gated to super_admin; Yahoo Finance keyless providers
- [x] Provider whitelist (ENABLED_PROVIDERS); default auto-categorize rule at signup
- [x] Skip onboarding flow at signup; rebrand; legal pages; /contact page
