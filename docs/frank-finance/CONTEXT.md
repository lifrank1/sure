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
- `SNAPTRADE_CLIENT_ID/CONSUMER_KEY` — test tier (5 connections); brokerages incl.
  Fidelity (Plaid can't do Fidelity). Instance-wide creds trigger hosted-mode
  behavior: auto-create item on connect, auto-link discovered accounts.
- `OPENAI_ACCESS_TOKEN/URI_BASE/MODEL` — Gemini via OpenAI-compat endpoint,
  model gemini-3.1-flash-lite, LLM_JSON_MODE=json_object (strict mode fails).
- `ENABLED_PROVIDERS=plaid` — UI provider whitelist (prefix-matches plaid_us/eu).
  Add snaptrade/simplefin here to surface their panels for all users.
- `SECURITIES_PROVIDERS=yahoo_finance`, `EXCHANGE_RATE_PROVIDER=yahoo_finance` —
  keyless market data.
- `REQUIRE_EMAIL_CONFIRMATION=false` — TEMPORARY until Resend domain verified
  (erech.app pending DNS records at Namecheap); SMTP vars already set.
- `AI_CHAT_UI_ENABLED=false` — hides all AI-chat entry points (header toggle,
  right panel, mobile Assistant tab) while chat 400s on Gemini tool-calls.
  Flip to true (or unset) once chat is fixed; panel-width + toggle-persistence
  bugs were fixed 2026-07-06 so the UI works when re-enabled.

## Product decisions

- Signups open to the internet (Frank's call). First user = super_admin = Frank.
- Instance settings (Settings > Self-Hosting) gated super_admin-only.
- Users never handle provider keys: Plaid Link + SnapTrade portal flows.
- Every new family gets an active auto-categorize rule (runs on sync).
- Onboarding flow skipped at signup (defaults: USD/en).

## Current status (updated 2026-07-05, post UX-overhaul)

All three UX phases from the Copilot-benchmark audit are shipped and verified
live: space reclamation, review loop (needs_review + dashboard card + drawer
confirm), actionable dashboard cards (monthly spending, next-two-weeks
recurrings), sankey relocated to Reports, Recurring in nav, header labels.
See ROADMAP.md checkboxes for the full ledger.

Waiting on Frank (only he can do these):
1. Resend: verify erech.app domain (DNS records at Namecheap) -> then set
   REQUIRE_EMAIL_CONFIRMATION=true and re-test signup email
2. Railway dashboard: usage alerts ($8 soft / $15 hard) + Postgres backups
3. Create a July budget (upgrades the Monthly-spending card to "$X left")
4. SnapTrade is on TEST tier (5 connections) — apply for production when
   user demand justifies (~$1.50/user/mo, ask for Fidelity enablement)

Second user f.li.865985@gmail.com is Frank's own test account (safe to delete).

## Known issues / gotchas

- AI chat 400s on function-call round-trip with Gemini (works for first call;
  fails when tool results are sent back). Suspect message format compatibility.
- SnapTrade balance rule: prefer API total unless it's below holdings value
  (Fidelity sweeps cash into SPAXX → double-count guard in
  SnaptradeAccount::Processor#calculate_total_balance).
- Local dev DB (Docker, port 5433) is Frank's PERSONAL data — do not wipe.
  Tests must run on host with separate test DB (see CLAUDE.md warnings).
- Upstream merges: `git fetch upstream && git merge upstream/main` — our changes
  are deliberately additive/env-gated to minimize conflicts.
