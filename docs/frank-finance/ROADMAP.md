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

## Security + UX audit (2026-07-07, 4-agent team: 2 security, 2 UX)

Full report in session history. Nothing catastrophic — no cross-family data
leak, no SQL injection, no secret exposure, no SSRF; password/session/
impersonation well-built. All findings below fixed and shipped 2026-07-07:

Security:
- [x] S1 (High) invitations no longer auto-reassign an existing user's family;
      both new and existing users accept from their own session; uniform
      response removes the email-enumeration oracle
- [x] S2 (High) CSV/formula-injection guard (CsvSafe) on both export paths
      (reports Google-Sheets export + full data export)
- [x] S3 (Med) Rack::Attack throttles for POST /sessions and POST /mfa/verify
- [x] S4 (Med) Content-Security-Policy enabled (was fully disabled): nonce-based
      script-src (all inline scripts nonced; inline onclick/javascript: handlers
      replaced with a stop-propagation Stimulus controller), inline styles
      allowed (width attrs), permissive img for logos
- [x] S5/S6 (Med/Low) bulk transaction update + mark_reviewed scoped to
      writable/accessible accounts (per-account sharing can't be bypassed);
      merchant website_url format validation

UX/a11y:
- [x] U1 branded 404/500/422 pages (was raw Rails boilerplate)
- [x] U2 text-subdued darkened to gray-500 in light mode (WCAG 1.4.3, was 2.6:1)
- [x] U3 getting-started "connect" step only shown to admins (non-admins can't
      add accounts — was a dead end)
- [x] U4 mobile bottom bar rebalanced to 5 incl. Accounts; full nav added to
      mobile slide-out so every destination stays reachable
- [x] U5 persistent last-synced/syncing indicator in the app header
- [x] U6 "Clear all filters" action on no-results transactions
- [x] U8 form a11y: required-field asterisk aria-hidden + sr-only "(required)";
      password requirements get list semantics + shape (not color-only) state +
      sr-only met/not-met; getting-started progressbar role; legal copy to i18n
- [x] U7 (scoped) explicit month-year label on Categories

Deliberately NOT done (conflicts with Frank's explicit earlier choices, noted):
- Demoting Categories/Recurring out of the sidebar (Frank asked for the
  Copilot-shaped sidebar with them present) — only fixed the mobile gap
- Removing the Categories spending overview (Frank requested it) — kept
- Investments page tabs/section-nav + full period-picker unification —
  larger redesign, deferred

## Copilot Money parity pass (2026-07-06, benchmarked in-app side by side)

Late additions (2026-07-11, browser-verified on prod):
- [x] Monthly spending pace card (Copilot's spend-vs-pace chart): cumulative
      MTD spending line vs dashed even-pace guide, over/under badge at today.
      Target = budget, else avg monthly money-IN of last 3 full months
      (8b90ee67 — "you bring in $X/mo on average" + set-budget CTA; pacing
      under it means spending less than you earn), hidden if neither.
      IncomeStatement::DailyExpenses mirrors Totals scoping grouped by
      date — verified sums exactly to expense_split.spending. New default
      top card (spending_pace, net_worth_chart, outflows_donut, ...);
      Frank's saved order updated in-place via SQL (saved prefs override
      the default). Greeting subtitle removed same commit.
- [x] Spending donut compacted: 176px donut left of the category list at @md
      container width (was stacked; @2xl/@lg never fired in the two-column
      grid — measure the real container before picking breakpoints)

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

Redundancy pass (same day, after the new pages landed): dashboard Balance
Sheet card deleted (sidebar + Accounts page cover it); dashboard Investments
card compacted to value + total return + top-3 + link; Monthly spending card
merged into the Spending donut (budget line in its header); Reports dropped
its Net Worth and Investment Performance sections (print export keeps both;
Gains by Tax Treatment moved to /investments, calc now lives in
InvestmentStatement#gains_by_tax_treatment); donut list shows top 5 + "All
categories" link; Accounts/Categories removed from settings nav. Each page
now has one job: Dashboard = today, Accounts = connections, Investments =
portfolio, Categories = spend vs budget, Budgets = allocation editor,
Reports = history/analysis, Recurring = bills. Budgets↔Categories full merge
deliberately deferred.

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

## Cohort benchmarking — "How you compare" (/compare), shipped 2026-07-08

Benchmarks a user against PUBLIC-DATA cohorts (age band × metro × income),
never other users. Private-by-construction; works from first session.
Design spec by a UX/PM subagent; grounded in existing DS::/UI:: components.

Shipped (v1 vertical slice):
- [x] PublicBenchmark: cached fetchers — BLS CEX (keyless), Zillow (keyless),
      Census (CENSUS_API_KEY), FRED (FRED_API_KEY), Fed SCF (static table)
- [x] Cohort: age-band × metro resolver (20 metros curated → national fallback),
      detected income; age_band+metro stored in user.preferences["compare"]
- [x] SavingsRate: take-home rate (income − spending) from linked accounts
- [x] /compare page: 5 cards (savings, food, subscriptions, rent-to-income,
      net-worth percentile), reusable _card partial
- [x] Psychology per spec: amber-not-red for "worse", savings-led / net-worth
      last, "Typical for people like you" language, per-card source disclosure,
      national fallback so nothing is ever blank
- [x] Desktop nav row "Compare"; inline age/metro capture form; privacy alert

Deferred fast-follows:
- [x] BROWSER-VERIFY /compare (2026-07-09): renders clean, age form round-trips,
      cards + disclosures + sources OK, no console/CSP errors. Found and fixed
      forward 3 bugs (9ae5d523): net-worth card 500 (`.amount` on BigDecimal —
      only fired once an age band was saved, so it hid until form use),
      inverted percentile label ("Top 70%" at the 70th percentile → now
      "Nth percentile"), and subscriptions CTA said "Set a dining budget"
      (shared cta.set_budget key → per-card cards.<key>.cta)
- [ ] Rent card is invisible for national-numbers users with no rent-categorized
      transactions (needs metro OR detected rent) — consider a 30%-guideline
      fallback framing instead of hiding the card

## Financial fitness score + leagues (/compare hero), shipped 2026-07-09

Proprietary 0-1000 composite behind Bronze(0)/Silver(550)/Gold(700)/
Diamond(850) leagues. Behavior-weighted BY DESIGN — savings rate 25%, cash
buffer 25%, revolving debt 20%, momentum 20%, habits 10% — so rank is
movable regardless of wealth (net-worth standing stays the percentile
card's job). Pillars map raw metrics through anchor curves
(FinancialHealth::Curve, pure/Rails-free) calibrated to public stats;
missing data LOCKS a pillar (weight renormalized, never zero) and
MIN_AVAILABLE_WEIGHT=0.5 stops a rank resting on slivers (habits-only was
scoring Gold in testing). Provisional badge under 30 days history. Daily
snapshots (lazy on visit + FinancialHealthSnapshotJob 4:15 UTC cron) power
the weekly delta chip. Hero is fully rescued — can never 500 /compare.
Verified on prod 2026-07-09: Frank = Bronze 507, math exact, CTA targets
weakest pillar, no console errors.

Fast-follows:
- [ ] Promotion/demotion hysteresis (2 wks above to promote / 3 below to
      demote) once snapshot history densifies; promotion celebration modal
- [ ] Dashboard teaser badge (this supersedes the /compare dashboard-teaser
      fast-follow above)
- [ ] Save pillar (90-day) vs savings-rate card (30-day) can disagree on the
      same page (83 vs -100% on launch day) — align windows or label them
- [ ] Buffer pillar reads near-zero for Frank (~$60k/mo implied 90-day spend
      vs $9.6k liquid) — sanity-check expense_split window for one-off
      lumps (tuition/rent?) before tuning anchors
- [ ] Anchor tuning pass after a few weeks of snapshots
- [ ] "Wrapped"-style share card on promotion ("I hit Gold")
- [ ] Add payroll-401k contributions to savings rate (currently take-home only)
- [ ] Dashboard teaser card (hero metric + "See all 5 →")
- [ ] Polished DS::Dialog onboarding modal (v1 uses an inline form)
- [ ] Settings "About you" section for age/metro (note: "Use national numbers"
      stores metro as nil, indistinguishable from unanswered, so the inline
      onboarding form re-shows forever — it's also currently the only edit
      affordance, so fix both together)
- [ ] "Wrapped"-style shareable card (agent recommended deferring)
- [ ] Expand metro list beyond 20; city typeahead → CBSA resolution

## Onboarding flow, shipped 2026-07-14 (1eb335e8)

3-step wizard for FRESH family creators only (invited/invite-only-default
signups skip it): outcome screen + founder note -> personalize (age/metro
-> compare cohort incl. metro_answered; goal -> dashboard section order
via OnboardingsController::GOAL_SECTION_ORDERS) -> connect (trust copy +
existing account hub in the modal frame). Reuses upstream wizard rails
(/onboarding routes, wizard layout, Onboardable bouncer) — upstream
goals/trial views left in place unlinked. Completion stamped server-side;
every screen skippable; getting-started checklist backstops skips.
Built with a 5-agent subsystem map + 4-lens adversarial review (11
findings, 8 confirmed and fixed pre-deploy, incl.: email-verification
links bounced for un-onboarded users — /email_confirmation/signup added
to Onboardable exclusions; metro select needed a blank "Decide later" so
untouched submits don't lock the cohort; "Edit my cohort" resurrections
via /compare?edit_cohort=1). Browser-verified on prod.

Fast-follows:
- [ ] Narrated sync progress after first connect ("Found 4 accounts →
      importing 23 months → categorizing…") — the dead-air killer
- [ ] Social login (Google/Apple) — biggest remaining signup-friction gap

## Signup email verification, shipped 2026-07-12 (f30c7d09)

Soft gate: new signups get a 3-day verification link + persistent banner
with resend; nothing is blocked (the win is guaranteed password recovery).
Invited users auto-confirm; all pre-existing users grandfathered
(users.confirmed_at backfill). Same Setting.require_email_confirmation
gates this AND the email-change flow. Verified on prod: migration/backfill,
garbage-token rejection; mailer verified in the prod image (full e2e needs
a real signup — account creation is off-limits for the agent).

## AI auto-categorization fixes, 2026-07-12 (9489f660)

Root causes of the uncategorized backlog (see CONTEXT gotchas): phantom
category names hardcoded in the Gemini prompt ("Salary" etc. — echoed by
the model, never matching) + missing Insurance/Fees in the trimmed default
set (now 15; backfilled into the Jul-6 family via SQL). Verified live:
payroll → Income. Remaining uncategorized is the legitimate long tail —
Categorize-wizard territory.

Fast-follows:
- [ ] Normalize LLM category-name matching (case/whitespace-insensitive) in
      Family::AutoCategorizer — exact string match is one typo from a miss
- [ ] Family sync resilience: one dead provider item (Frank's stale
      test-client SnapTrade connection, 401s nightly) fails the ENTIRE
      family sync, so post-sync rule runs never fire for that family —
      rescue per-item and continue (also see CONTEXT "Waiting on Frank" #3)
