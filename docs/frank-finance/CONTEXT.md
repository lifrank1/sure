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

## Product decisions

- Signups open to the internet (Frank's call). First user = super_admin = Frank.
- Instance settings (Settings > Self-Hosting) gated super_admin-only.
- Users never handle provider keys: Plaid Link + SnapTrade portal flows.
- Every new family gets an active auto-categorize rule (runs on sync).
- Onboarding flow skipped at signup (defaults: USD/en).

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
