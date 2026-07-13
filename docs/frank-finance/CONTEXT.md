# Frank Finance — Operating Context

> Durable context for LLM sessions and future contributors. Keep short; update
> when architecture-level facts change. Progress tracking: [ROADMAP.md](ROADMAP.md).

## What this is

Hosted multi-tenant personal-finance app at https://finance.erech.app, run by
Frank Li (lifranksites@gmail.com contact; super_admin account). Fork of
we-promise/sure (AGPLv3) — private repo `lifrank1/erech-finance` is the deploy
source; public fork `lifrank1/sure` mirrors main for the AGPL "Source" footer
link. Push to BOTH remotes on every change.

## Infrastructure

- Railway project "sure-finance": web + worker (Sidekiq) + Postgres + Redis.
  Deploys automatically on push to private repo main.
- Domain: finance.erech.app (Namecheap DNS → Railway).
- Encryption-at-rest keys + SECRET_KEY_BASE set as env vars — NEVER change them.

## Key env-var decisions (all on both web + worker)

- `PLAID_*` — production keys; banks/credit cards. Redirect URI allow-listed:
  https://finance.erech.app/accounts
- `SNAPTRADE_CLIENT_ID/CONSUMER_KEY` — PRODUCTION as of 2026-07-07 (client
  ERECH-GIENC, ~$1.50/connected user/mo, no connection cap); brokerages incl.
  Fidelity (Plaid can't do Fidelity). Instance-wide creds trigger hosted-mode
  behavior: auto-create item on connect, auto-link discovered accounts.
  NOTE: Frank's original connections were made on the old test client
  (ERECH-TEST-TTUUE) and had to be reconnected after the swap — test/prod
  user pools are separate.
- `OPENAI_ACCESS_TOKEN/URI_BASE/MODEL` — Gemini via OpenAI-compat endpoint,
  model gemini-3.1-flash-lite, LLM_JSON_MODE=json_object (strict mode fails).
- `ENABLED_PROVIDERS=plaid` — UI provider whitelist (prefix-matches plaid_us/eu).
  Add snaptrade/simplefin here to surface their panels for all users.
- `SECURITIES_PROVIDERS=yahoo_finance`, `EXCHANGE_RATE_PROVIDER=yahoo_finance` —
  keyless market data.
- Email WORKING end-to-end (2026-07-07), three fixes were needed:
  1. `EMAIL_SENDER=noreply@in.erech.app` — reuses the Resend-verified
     renter-concierge subdomain (root erech.app verification is optional
     polish later; do NOT touch in.erech.app records — same account, both
     domains coexist)
  2. `APP_DOMAIN=finance.erech.app` — was never set; mailer templates
     crashed with "Missing host to link to" on both services
  3. `SMTP_PORT=2465` — Railway Hobby blocks standard SMTP egress
     (25/465/587); Resend's alternate port 2465 (implicit TLS) works
  `REQUIRE_EMAIL_CONFIRMATION=true` — as of 2026-07-12 (f30c7d09) gates
  BOTH the email-change flow AND signup verification: new signups get a
  3-day verification link + persistent in-app banner w/ resend (soft gate,
  nothing blocked); invited users auto-confirm; all pre-existing users
  grandfathered via users.confirmed_at backfill. Resend API key on Railway
  is restricted/send-only; domain management needs the Resend dashboard.
- `AI_CHAT_UI_ENABLED=true` — kill switch for all AI-chat entry points (header
  toggle, right panel, mobile Assistant tab); set false to hide them. Chat's
  Gemini tool-call 400 (history replay sent jsonb Hash arguments; Gemini
  requires JSON strings) fixed 2026-07-06.
- `CENSUS_API_KEY` / `FRED_API_KEY` — free public-data keys for the cohort
  benchmarking feature (see below). Read-only; both should be rotated (they
  passed through a chat transcript). BLS CEX + Zillow need no key.

## Product decisions

- Signups open to the internet (Frank's call). First user = super_admin = Frank.
- Instance settings (Settings > Self-Hosting) gated super_admin-only.
- Users never handle provider keys: Plaid Link + SnapTrade portal flows.
- Every new family gets an active auto-categorize rule (runs on sync).
- Onboarding flow skipped at signup (defaults: USD/en).

## Current status (updated 2026-07-13)

Shipped 2026-07-11/12: Monthly spending pace card (dashboard top-left;
target = budget else avg monthly money-in), compact donut layout, widget
reorder (spending_pace, net_worth, donut, ...), signup email verification
(soft gate — see env-var section), AI categorization fixes (see gotchas).
All browser- or prod-verified; ledger in ROADMAP.

Security + UX audit (2026-07-07) shipped: all findings fixed and deployed —
invite-consent, CSV-injection guard, login/MFA rate limits, sharing scopes,
CSP (browser-verified), branded error pages, contrast, clear-filters, form
a11y, slimmer nav, header sync status. SnapTrade is PRODUCTION (client
ERECH-GIENC) as of 2026-07-07 — no connection cap; Frank must reconnect his
own Fidelity/Robinhood (test/prod user pools are separate).

Financial fitness score + leagues shipped 2026-07-09 as the /compare hero:
0-1000 behavior-weighted composite (FinancialHealth::Score/Rank/Snapshot),
Bronze/Silver/Gold/Diamond bands, daily snapshots (lazy + 4:15 UTC cron),
locked pillars for missing data, provisional <30d. Verified on prod
(Frank = Bronze 507). See ROADMAP for pillar weights and fast-follows.

Cohort benchmarking ("How you compare", /compare) shipped 2026-07-08 as a v1
vertical slice — see ROADMAP for the ledger and the deferred fast-follows.
Browser-verified 2026-07-09 on prod: cards, age form, disclosures, no
console/CSP errors. Three bugs found in verification fixed forward
(9ae5d523), incl. a 500 that fired only after an age band was saved
(net_worth is BigDecimal, not Money — don't call .amount on it). Frank's
cohort is set to under-25 + national numbers. Rent card stays hidden until
a metro is chosen or rent-categorized transactions exist.

Waiting on Frank (only he can do these):
1. Rotate CENSUS_API_KEY + FRED_API_KEY (passed through chat; both free to
   reissue at api.census.gov/data/key_signup.html and fredaccount.stlouisfed.org)
2. Railway dashboard: usage alerts ($8 soft; hard limit STOPS services — use
   $25-30 or skip). Backups already DONE (db-backup service, nightly pg_dump).
3. URGENT-ish: the dead test-client SnapTrade item (b6e792fd) 401s every
   night and has FAILED Frank's entire family sync since 2026-07-08 (stale
   "Updated Xd ago" header, no nightly rule runs). Fix = reconnect Fidelity
   via SnapTrade portal (prod client), then remove the dead connection in
   the app (removal deletes that connection's accounts/history — Frank's
   call, do NOT do it for him). Consider a code fix so one dead provider
   item doesn't fail the whole family sync.
4. Create a July budget (upgrades the Spending card to "$X left")
5. (optional) Root-domain sender (noreply@erech.app): no Resend/Namecheap
   MCP exists (checked 2026-07-12) and none is needed — Frank creates a
   FULL-ACCESS Resend API key and puts it on Railway as RESEND_ADMIN_KEY
   (not through chat); agent then registers the domain via API, hands him
   ~3 DNS records to paste into Namecheap (root erech.app is a clean slate,
   verified — no conflict with in.erech.app), polls verification, flips
   EMAIL_SENDER. Namecheap API not worth enabling (eligibility gates).
   Email already WORKS via in.erech.app.
6. Approve deleting the 2 unused categories (Mortgage / Rent, Sports & Fitness)

Second user f.li.865985@gmail.com is Frank's own test account (safe to delete).

Uncategorized-backlog root causes found + fixed 2026-07-12 (9489f660): the
simple/Gemini auto-categorize prompt hardcoded phantom category names
("Salary" for payroll — obediently echoed by the model, never matching, so
payroll stayed uncategorized forever); default category set lacked
Insurance + Fees (added, 13→15, and backfilled into the Jul-6 family).
Verified live: payroll rows now land in Income. Remaining uncategorized is
the correct long tail (ATM cash, P2P, expense-classified payroll
reversals) — Categorize-wizard territory, not a bug.

## Known issues / gotchas
- DEPLOY GOTCHA (learned the hard way 2026-07-08): main auto-deploys to
  PROD and boot-time errors 502 the ENTIRE site, not just the new page.
  `ruby -c` on the host (Ruby 3.4.2) is NOT a sufficient gate — it passed a
  `next`-in-begin/end that the server's Ruby 3.4.0 rejected as a SyntaxError,
  taking the site down. For risky/new code, deploy a feature branch to a
  Railway PREVIEW environment first rather than merging straight to main.
- Cohort benchmarking internals: PublicBenchmark (cached public-data fetchers),
  Cohort (age-band × metro resolver; 20 metros curated, else national),
  SavingsRate (take-home rate = income − spending; does NOT yet add payroll
  401k contributions — that's the deferred enhancement). age_band + metro live
  in user.preferences["compare"]. /compare nav row is desktop_only.
- SnapTrade balance rule: prefer API total unless it's below holdings value
  (Fidelity sweeps cash into SPAXX → double-count guard in
  SnaptradeAccount::Processor#calculate_total_balance).
- Local dev DB (Docker, port 5433) is Frank's PERSONAL data — do not wipe.
  Tests must run on host with separate test DB (see CLAUDE.md warnings).
- Upstream merges: `git fetch upstream && git merge upstream/main` — our changes
  are deliberately additive/env-gated to minimize conflicts.
