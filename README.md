# hcb-testing

my test of hack club's hcb but ran locally because i feel like it (powered by claude code tm)

## What this is

This repo doesn't vendor the [hackclub/hcb](https://github.com/hackclub/hcb) source
(it's a big app, and already public) — it's a small overlay of patches +
notes for running a **fully local** copy of HCB, with:

- No real Stripe / Column / Twilio / TaxBandits / AWS credentials required.
- Card issuing "works" (issuing a virtual/physical card succeeds instantly
  and looks real in the UI) via a local fake instead of hitting Stripe.
- A demo organization ("Hack Club Megafund") seeded with a **$25,000,000.00**
  balance.
- The existing built-in HCB admin panel, using the existing dev seed admin
  account.

Nothing here talks to the internet for money movement — it's a sandbox for
poking at the HCB UI/admin panel, not a real bank.

## Setup

1. Clone HCB and check out the app:
   ```bash
   git clone https://github.com/hackclub/hcb.git
   cd hcb
   ```

2. Ruby/Node version note: if you don't have the exact pinned versions
   (see `.ruby-version` / `.node-version`), you can usually get away with a
   nearby version locally:
   - `bundle install` (if it complains about the Ruby version, either
     install the pinned version or edit `.ruby-version` to match what you
     have)
   - `yarn install --ignore-engines` (if it complains about the Node
     version)

3. Postgres + Redis running locally (no Docker required — just install
   Postgres 16 and Redis and start them; `postgres://postgres@127.0.0.1:5432`
   works with a passwordless local `postgres` role for this purpose).

4. Copy `patches/env.development.example` to `.env.development` in the HCB
   checkout. It intentionally leaves Stripe/Column/Twilio/TaxBandits/AWS
   keys blank — the app already treats blank Stripe creds as "dev mode" and
   generates a fake API key; the card-issuing patch below covers the rest.

5. Copy `patches/config/initializers/dev_fakes.rb` into HCB's
   `config/initializers/`. This is the important part — it fakes out the
   handful of Stripe Issuing API calls (`Card`/`Cardholder`/
   `PersonalizationDesign`/`File` create/retrieve/update) so that ordering
   and activating a card succeeds locally with realistic fake data (Visa,
   4242 last4, active status, etc.) instead of trying to reach
   `api.stripe.com`. It only activates in `Rails.env.development?` — it's a
   no-op anywhere else.

6. Also apply this one-line change to `config/initializers/stripe.rb`, so
   the "use a fake API key" behavior (which already existed for
   `Rails.env.test?`) also applies in development:
   ```ruby
   # before
   if api_key.blank? && Rails.env.test?
   # after
   if api_key.blank? && (Rails.env.test? || Rails.env.development?)
   ```

7. `bin/rails db:prepare` — creates + migrates + seeds the DB. HCB's own
   `db/seeds.rb` already creates a dev admin user
   (`admin@bank.engineering`, made an admin via `make_admin!`) and a pile
   of demo orgs.

8. Seed the $25M org: copy `patches/bin/seed_rich_org.rb` into HCB's `bin/`
   and run:
   ```bash
   bin/rails runner bin/seed_rich_org.rb
   ```
   This creates an event/org called "Hack Club Megafund" (slug `megafund`),
   invites the admin user as its organizer, deposits $25,000,000 across a
   few chunks (the `amount_cents` column is a 4-byte int, so one single
   $25M deposit overflows it), and sets its plan to fee-exempt
   (`Event::Plan::HackClubAffiliate`, like HCB's other internal/demo orgs)
   so the full $25M shows up as available balance instead of being reduced
   by the standard 7% platform fee.

9. Build JS/CSS assets once (only needed the first time / after JS
   changes):
   ```bash
   yarn --ignore-engines run build
   yarn --ignore-engines run build:css
   ```

10. Run the app:
    ```bash
    bin/rails server -b 0.0.0.0 -p 3000
    ```

## Using it

- Go to `http://localhost:3000/users/auth` and log in as
  `admin@bank.engineering`. There's no real email — HCB uses
  [letter_opener](https://github.com/ryanb/letter_opener) in development, so
  grab the login code from `http://localhost:3000/letter_opener`.
- The admin panel is at `http://localhost:3000/admin`.
- The $25M org is at `http://localhost:3000/megafund`.
- From the org, Cards → Order a card → Issue my card gives you a working
  fake virtual Visa card (4242 last4, active, full balance as its spending
  limit) instantly, no Stripe account needed.

## Why not a public/hosted link

This was built out in an ephemeral sandbox container with no inbound
internet access, and GitHub Pages (or any static host) can't run a
Postgres/Redis-backed Rails app anyway — so this is set up for **local
only** use, per how this was scoped. If you want an actual publicly
reachable demo, the real move is deploying HCB (with its Docker/Heroku
tooling) to a host like Render/Fly/Railway with its own Postgres+Redis,
which is a bigger, separate task.
