# Deploy hardening (#160)

The backend runs on Fly.io as app **`tradeiq-backend`** (https://tradeiq-backend.fly.dev,
region `lhr`), against Supabase Postgres in `eu-west-1`. It started as a test
deployment with demo data. This page covers the settings to have in place before it
holds anything real.

Deploys are manual: `fly deploy` run from `backend/`, which uses `backend/fly.toml`.
No GitHub Actions workflow deploys. `backend-ci`, `app-ci`, `security` and
`assistant-evals` only test, scan and evaluate. Migrations run on each deploy through
`[deploy] release_command = "npx prisma migrate deploy"`. If that command fails, the
deploy aborts and the old release keeps serving.

Changes to `fly.toml` only reach the live app on the next `fly deploy`.

---

## 1. CORS

`backend/src/app.ts` chooses the policy once, at startup:

| `NODE_ENV` | `CORS_ORIGINS` | Policy |
|---|---|---|
| anything but `production` | unset or empty | **Open.** `flutter run -d chrome` picks a random port, so no fixed dev origin exists to allowlist. |
| `production` | unset or empty | **Closed.** No `Access-Control-Allow-Origin` is sent, so browsers refuse cross-origin reads. The app logs a `[cors] CORS_ORIGINS is not set in production` warning at startup. |
| any | comma-separated list | Only the listed origins get the header. Whitespace around entries is trimmed. |

Requests with no `Origin` header work under every policy. That covers the Flutter
mobile app, curl, health checks and server-to-server webhooks. CORS is enforced by
browsers only, so it is not an access control for those clients.

Production gets `NODE_ENV=production` from both `fly.toml` `[env]` and the Dockerfile.

**No web build of the manager console is deployed today.** No hosting config exists
for GitHub Pages, Firebase, Netlify, Vercel or a static Fly app, and `app-ci` builds
web only as a compile check. `CORS_ORIGINS` should therefore stay **unset** for now.
When a console is deployed, set it to the console's exact origin. That means scheme
plus host plus any non-default port, with no path and no trailing slash:

```sh
fly secrets set -a tradeiq-backend CORS_ORIGINS="https://<console-host>"
```

## 2. One machine always on

`fly.toml` sets `min_machines_running = 1`, with `auto_stop_machines = "stop"` and
`auto_start_machines = true` left on. One machine stays up, so the first request after
a quiet spell no longer waits on a cold start. Any machines above that one still stop
when idle and start on demand.

**Cost.** The VM is `shared-cpu-1x` with 512 MB. Running it around the clock is a
small fixed monthly charge instead of near zero. Check the current rate on Fly's
pricing page before relying on a figure. Fly apps are often created with two machines,
so run `fly status` to see how many exist. Only one of them is kept running.

A useful side effect: the webhook-delivery and report-schedule workers poll the
database from the running machine. That activity should also stop a Free-plan
Supabase project from being paused for inactivity (see section 4). Supabase does not
spell out exactly what counts as activity, so do not rely on this.

## 3. Demo account passwords

The demo accounts are the nine `USERS` in `backend/scripts/seed/catalog.ts`: one
admin, two managers and six field agents. All of them are seeded with one shared
password, defined as `DEMO_PASSWORD` in that same file. That password is public: it is
committed to the repo and repeated in the onboarding docs.

### Seeding

- Locally, `npm run seed` still uses the published default so onboarding keeps working.
- With `NODE_ENV=production`, the seed already refuses to run without `--force`,
  because it deletes and rebuilds the demo tenant. It now **also** refuses the
  published default. You must set `SEED_DEMO_PASSWORD` to a password of at least 12
  characters that is not the default. The seed checks this before deleting anything,
  and never prints a supplied password.

The seed only recognises production by `NODE_ENV`. If you point a local shell at the
production database, set `NODE_ENV=production` in that shell too.

### Rotation: `npm run rotate-demo-passwords`

The script gives each demo account its own 32-character random password. Accounts are
matched by email, and the hashing is the same as login uses (`hashPassword`, bcrypt
cost 10). It changes nothing else.

- `-- --dry-run` lists the accounts found and any demo emails missing from the
  database, then exits without changing anything.
- `-- <output-file>` rotates the passwords. The `email<TAB>password` lines go **only**
  to that file, which is created with mode 0600. The script refuses to run if the file
  already exists, and never writes passwords to stdout. The file is written before the
  database update and deleted again if the update fails.

**Sessions.** There is no session store and no refresh token to revoke. Login issues a
stateless JWT that is valid for 12 hours (#142). `requireAuth` re-checks `active`,
`role` and `clientId` on every request, but not the password. A token issued before a
rotation therefore stays valid until it expires. To end every session immediately,
rotate `JWT_SECRET`. That signs out every user, including the mobile app, and they
must log in again.

**Where to run it against production.** Run it from a trusted laptop, with the
production URL supplied for one command only. `fly ssh console -C` cannot work: the
runtime image contains only `dist/` and production dependencies, with no `scripts/`
and no `ts-node`. It would also leave the credentials file on the machine's disk until
you copied it off.

```sh
cd backend
# Supabase dashboard → Connect → Session pooler URI (port 5432). Pasted, not echoed,
# not saved to .env or shell history.
read -rs PROD_DATABASE_URL && export PROD_DATABASE_URL
DATABASE_URL="$PROD_DATABASE_URL" NODE_ENV=production npm run rotate-demo-passwords -- --dry-run
# Check that the "Target database:" line names the Supabase pooler host, then:
DATABASE_URL="$PROD_DATABASE_URL" NODE_ENV=production \
  npm run rotate-demo-passwords -- "$HOME/tradeiq-demo-creds-$(date +%F).txt"
unset PROD_DATABASE_URL
# Move the file's contents into the team password manager, then delete the file.
```

The script prints only the database host and name, never the credentials in the URL.
A `DATABASE_URL` set in the environment takes precedence over `backend/.env`.

If the file is lost before its contents are saved, run the rotation again with a new
path. That is the whole recovery, because nobody should need the old passwords back.

## 4. Backups

Sources: Supabase's official [Database Backups](https://supabase.com/docs/guides/platform/backups),
[PITR usage](https://supabase.com/docs/guides/platform/manage-your-usage/point-in-time-recovery),
[Backup and restore using the CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)
and [pricing](https://supabase.com/pricing) pages, read 2026-09-15.

The Supabase plan cannot be seen from the repository. Check it under Dashboard →
Organization → Billing. #160 describes the project as free tier.

| | Free | Pro |
|---|---|---|
| Price | $0 | from $25/month (includes $10 compute credit) |
| Daily backups | **None** | 7 days retention (Team: 14, Enterprise: up to 30) |
| Point-in-time recovery | Not available | Add-on: about $100/month for 7 days, $200 for 14, $400 for 28. Needs at least the Small compute add-on. Not covered by the spend cap. Worst-case RPO of 2 minutes. |
| Other | Paused after 1 week of inactivity. 500 MB database. | 8 GB disk included |

- **Free plan: nothing is backed up.** #160 says retention is "limited", but on Free
  there is no retention at all. Supabase says Free projects should "regularly export
  their data using the Supabase CLI `db dump` command and maintain off-site backups".
- On Pro and above, you restore from Dashboard → Database → Backups. The project is
  **unavailable while the restore runs**, and the downtime grows with database size.
  Restoring into a new project goes through "Duplicate Project".
- Supabase backups do not include Storage API objects. TradeIQ does not use Supabase
  Storage: photos are base64 data URLs in the `photos` table. A database backup
  therefore covers photos, but it also makes the dumps large.

### Restore path today (Free plan)

The only restore path is a dump you took yourself. To restore:

1. Create a new Supabase project in the same region.
2. Load the dump with `psql` for a plain SQL dump, or `pg_restore` for a custom-format
   dump.
3. Run `fly secrets set -a tradeiq-backend DATABASE_URL="<new session-pooler URL>"`.
   This restarts the machines against the new database.
4. Check `/health`, a login, and `GET /outlets`.

Manual dump, using the session pooler URL. The `pg_dump` major version must be at
least the server's:

```sh
pg_dump "$PROD_DATABASE_URL" --schema=public --format=custom --no-owner --no-privileges \
  --file "$HOME/tradeiq-backups/tradeiq-$(date +%F).dump" && chmod 600 "$HOME/tradeiq-backups/"*.dump
```

### Gaps and recommendation

1. **Now, while the data is disposable:** take a manual dump before each risky step
   (password rotation, destructive migrations). Test a restore into a scratch project
   once, so the restore path is proven to work.
2. **Before real outlets, agents or photos:** upgrade to **Pro**. That gives daily
   backups with 7-day retention and a dashboard restore, for $25/month. Scheduled
   exports alone leave you owning retention, encryption and restore testing, which is
   the gap a paid plan closes.
3. **Also, for off-site copies independent of Supabase:** add a scheduled
   `pg_dump` job, for example nightly in GitHub Actions, with the URL as a repository
   secret. Encrypt the dump before upload and send it to private object storage with
   lifecycle retention, not to a workflow artifact.
4. **When field data becomes costly to re-collect:** enable PITR (from about
   $100/month plus Small compute). A day of lost visits is a day of agents' work.
