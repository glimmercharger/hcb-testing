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
- **No login screen at all** — every request auto-authenticates as the
  admin account, dev-only.
- **No phone verification required** to issue a card — there's no Twilio
  account locally to send/verify a real SMS code against, so that gate is
  bypassed too, dev-only.
- **Links work wherever you're actually browsing from** — absolute links
  (e.g. a draft application's "view" link) are built from the current
  request's host instead of a hardcoded `localhost:3000`, so they still
  work when reached through the live-demo tunnel instead of a plain local
  server.

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

7. Copy `patches/config/initializers/dev_auto_login.rb` into HCB's
   `config/initializers/`. This removes the login gate entirely: instead of
   HCB's normal magic-link/email-code flow, every request is
   auto-authenticated as the seeded dev admin (`admin@bank.engineering`).
   There's no login page to click through — visiting the app just drops you
   in, already signed in as admin. Dev-only, same as the other patches.

8. Copy `patches/config/initializers/dev_dynamic_host.rb` into HCB's
   `config/initializers/`. HCB normally pins the host used to build
   absolute links (`_url` helpers, e.g. a fiscal sponsorship application's
   "view" link) to whatever `TEST_URL_HOST` is set to. If you're reaching
   the app through something other than plain `localhost:3000` (a tunnel,
   a forwarded port), those links would otherwise point at literal
   `localhost:3000` and fail to open. This makes controllers build those
   links from the *current request's* host/protocol instead, so they
   always match wherever you actually browsed in from.

9. Copy `patches/config/initializers/dev_fake_stripe_dashboard_links.rb`
   into HCB's `config/initializers/`. The admin panel has "View card/
   cardholder/personalization design on Stripe" buttons that link straight
   to `dashboard.stripe.com` using the object's Stripe ID -- since those
   IDs are fake (see `dev_fakes.rb`), that button would send you to a real
   Stripe dashboard page for an object that doesn't exist there. This
   neutralizes the link (`#`) whenever the ID is one of ours.

10. `bin/rails db:prepare` — creates + migrates + seeds the DB. HCB's own
   `db/seeds.rb` already creates a dev admin user
   (`admin@bank.engineering`, made an admin via `make_admin!`) and a pile
   of demo orgs.

11. Seed the $25M org: copy `patches/bin/seed_rich_org.rb` into HCB's `bin/`
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

12. Build JS/CSS assets once (only needed the first time / after JS
    changes):
    ```bash
    yarn --ignore-engines run build
    yarn --ignore-engines run build:css
    ```

13. Run the app:
    ```bash
    bin/rails server -b 0.0.0.0 -p 3000
    ```

## Using it

- Just go to `http://localhost:3000` — no login, you're dropped straight in
  as the admin (`admin@bank.engineering`).
- The admin panel is at `http://localhost:3000/admin`.
- The $25M org is at `http://localhost:3000/megafund`.
- From the org, Cards → Order a card → Issue my card gives you a working
  fake virtual Visa card (4242 last4, active, full balance as its spending
  limit) instantly, no Stripe account needed.

## Getting a live link (no local install needed)

`.github/workflows/live-demo.yml` runs this whole setup inside a GitHub
Actions runner (which, unlike a typical sandboxed agent container, has
normal internet access) and opens a [Cloudflare
Tunnel](https://github.com/cloudflare/cloudflared) quick tunnel to it. That
gets you a real, working `https://*.trycloudflare.com` URL with nothing
installed on your own machine.

**To get a link:**
1. Go to the **Actions** tab → **Live demo** workflow → **Run workflow**.
2. Wait a few minutes for it to build, seed, and boot.
3. Open the run, and check the **Summary** page (or the last step's log) —
   the link is printed there as soon as the tunnel comes up.

**To get a *new* link:** just run the workflow again — no push needed.
Starting a new run automatically cancels whichever run is currently live
(same `concurrency` group), so re-running is literally how you rotate the
link.

**To end the preview whenever you want:** open the running workflow run
and click **Cancel workflow** (top right of the run's page). The last step
traps the cancellation and explicitly kills the tunnel and Rails server
before the run ends, so the link stops working immediately — you don't
have to wait for `duration_minutes` to run out.

Things worth knowing:
- **It's temporary.** The link dies the moment the job ends — either
  because you hit the `duration_minutes` input (default 60, capped at 300)
  or GitHub's hard 6-hour job limit.
- **The URL is random and unauthenticated Cloudflare-side** — anyone with
  the link gets in as admin (login is removed, see above), so don't leave
  a long-duration run going unattended if you're worried about who might
  stumble on the URL.
- Runs use this repo's GitHub Actions minutes — free/unmetered for public
  repos.

## Why not a permanent hosted link

A GitHub Actions run is inherently temporary — it's not a real host. If you
want an always-on, stable URL instead, the real move is deploying HCB
(with its own Docker/Heroku tooling) to a host like Render/Fly/Railway with
its own persistent Postgres+Redis — a bigger, separate task that needs your
own account/credentials there.
