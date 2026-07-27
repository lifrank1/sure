# Simplification Plan (approved 2026-07-27)

> Frank approved all 4 phases of the consolidation + human-complexity review.
> Source: two 6-agent audit fleets (surface inventories + human lenses),
> ~60 verified findings. This doc is the durable execution contract — each
> phase ships independently (map → build → adversarial review → verified
> deploy). Update checkboxes as slices land.

## End state

Nav = **Home · Transactions · Budgets · Compare**. Nothing else. No More
group. One inbox, one spending engine, one vocabulary.

## Phase 1 — Nav consolidation

- [x] 1a. SHIPPED 6691be2a, prod-verified 2026-07-27. Sankey → Home dashboard widget; Reports nav entry dies.
      PRE-WIRED: PagesController already includes CashflowSankeyBuildable,
      DASHBOARD_SECTION_LAYOUTS has a cashflow_sankey entry, dashboard.html.erb
      has cashflow-expand + fullscreen conditionals, partials already under
      pages/dashboard/. Work: compute income/expense/net totals over a widget
      period in #dashboard, add registry entry + default order append.
      /reports stays reachable as linkless power URL (CSV/Sheets export,
      trends table live there until missed/rescued).
- [x] 1b. SHIPPED 6691be2a, prod-verified 2026-07-27. To-review → Transactions "Needs review (N)" chip/filter + bulk
      mark-all in selection bar (endpoints are view-agnostic already:
      redirect_back_or_to + turbo_stream keyed review_row_<id>). Then the
      dashboard widget dies. Transaction::Search already supports
      q[needs_review] — it just has no UI control.
- [ ] 1c. Recurring page dies → Transactions "Upcoming" tab absorbs
      management (pause/resume/delete/cleanup/identify/stats; tab already
      renders the SAME partials _projected_transaction/_empty). TRAPS:
      paused rows are ONLY resumable on the page today; feature on/off
      toggle only lives there (move to a small settings row); widget query
      ignores the disabled flag (fix). Home widget links to the tab.
- [ ] 1d. Categories page dies → Budgets absorbs. Categories#index already
      loads the current Budget to render (it IS a read-only clone). Add
      edit/delete DS::Menu to budget category rows + allocation editor rows
      (modals are page-independent); merge + delete-all into a "Manage
      categories" modal from Budgets; retarget ~4 inbound categories_path
      links (donut "All categories", transactions kebab); budget show
      uncategorized row gains wizard link.
- [ ] 1e. Accounts TAB dies (page/routes stay — ~30 provider-flow return
      links + hardcoded Plaid JS redirect land on /accounts). Management
      console reframes as Settings → Connections (nav entry in settings
      sidebar); sidebar stays the viewing surface; per-account actions
      already live on account show/drawer. Archived-accounts listing must
      stay reachable (only place they're visible).

## Phase 2 — Lost moments (the retention fixes; funnel-verified churn)

- [ ] 2a. Post-Plaid-link redirect → root (not /accounts), and sync-aware
      first-run states everywhere: while family.syncing? with zero visible
      accounts, replace connect-prompt + "No accounts yet" + empty
      transactions page with ONE waiting state ("Pulling in your
      transactions — usually under a minute"), visible on mobile.
- [ ] 2b. Dead-connection = first-class state: dashboard banner ("Chase
      stopped syncing 5 days ago — Reconnect") + staleness threshold on the
      header chip (>48h = warning styling + fix-it link). Sync FAILURE gets
      a toast (today: success toasts, failures → Sentry only).
- [ ] 2c. One inbox: merge uncategorized banner + review queue into a
      single "Needs attention" surface with per-item reason. AI-run
      progress state replaces the banner while a RuleRun is pending
      (counts live on RuleRun) — no more silent no-op button.

## Phase 3 — Copy & corpse sweep (mostly locale-only)

- [ ] 3a. Vocabulary purge: "entry"→transaction/balance update (all
      locales); ONE name for balance updates; "Provider extras"→"From your
      bank" + kill raw JSON dump (or gate Debug); "Open matcher"/"Open
      merger"→task language; "for this family"→neutral; "allocations"→
      plain speech; A/M pill→words; "cohort"→"who I'm compared to";
      "Depository"→never shown; goals empty-state jargon; FX tabs copy.
- [ ] 3b. Delete upstream corpses: /onboarding/goals + /onboarding/trial
      (+ needs_subscription? branch, legacy 4-step nav partial, locale
      strings). Password section added to Settings > Security (page exists,
      nothing links to it — also fix its missing title `=`).
- [ ] 3c. Dialog fixes: account-delete confirm rewrite; MFA-disable
      title/body dup; category merge target/source speak; single verb for
      connect/add; one CTA on empty dashboard (not three).
- [ ] 3d. Gate remaining operator leaks: "Reset AI cache" menu item +
      Recent Runs table (super_admin), sync telemetry "Seen/Imported"
      panels (admin detail view), "Reset and preload" (super_admin),
      Bank Sync provider wall behind "Connect another service".

## Phase 4 — De-redundancy mechanics (deepest surgery)

- [ ] 4a. ONE spending engine: route every user-visible "spent" number
      through IncomeStatement#expense_split (today 3 engines / 6 surfaces
      disagree).
- [ ] 4b. Period pickers: one behavior (widget-local, persisted per widget,
      never mutate other pages' default_period); cut 12 options → ~5
      (This month / Last month / 3 months / Year / All time; long horizons
      only on net-worth/investment charts). Kill the Periodable
      default_period write-on-navigate.
- [ ] 4c. Categorization collapses to TWO UIs: inline badge popover +
      wizard (fold dashboard AI button + wizard AI form into one action).
- [ ] 4d. Transaction drawer tiering: Overview always; More options
      disclosure (merchant/tags/notes/attachments); Settings zoo behind
      one "Count this in my budget?" control (Yes / one-off / transfer);
      matcher/merger/convert-to-trade into overflow. Edit-wins silently
      (kill "Protected from sync" concept).
- [ ] 4e. Forms: manual account = type→form direct (kill re-asked method
      step); CSV import auto-detects separator + signage; budget setup
      pre-fills AI estimates (kill opt-in toggle); credit-card extras
      under disclosure; balance update = one modal.
- [ ] 4f. Concept demotions: tags hidden until used (zero-state pattern);
      rules builder demoted from transactions kebab (replace with
      "Always put X in Y?" at categorize time); merchants become invisible
      enrichment; investment activity dropdown stays in investment
      surfaces only; nav appearance one-way (once shown, stays).

## Full audit archives

Raw fleet outputs (file:line evidence for every claim above), local paths:
- Consolidation inventory: tasks/wdsvkur0w.output (6 surfaces, 121KB)
- Human lenses: tasks/wapqfty1h.output (6 lenses, 92KB)
under /private/tmp/claude-501/-Users-frankli-Cowork/5abb536f-593b-449f-b848-9c89bfff2b61/.
These are session-temp; the load-bearing conclusions are inlined above.
