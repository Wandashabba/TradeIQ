# Scheduled report email (#66)

Scheduled reports are delivered by **webhook** (`report.generated`) and by **email over SMTP**. Email works with any provider (Google Workspace, Microsoft 365, Amazon SES, Resend SMTP, …).

Email stays **off until SMTP is configured**. Until then, each run records an email delivery as `not_configured` with the reason. Nothing is queued and nothing retries.

## Environment variables

| Variable | Required | Notes |
| --- | --- | --- |
| `SMTP_HOST` | yes | e.g. `smtp.gmail.com`, `email-smtp.eu-west-1.amazonaws.com` |
| `SMTP_FROM` | yes | e.g. `TradeIQ Reports <reports@yourdomain.com>` |
| `SMTP_PORT` | no | Defaults to `465` when `SMTP_SECURE=true`, otherwise `587` |
| `SMTP_SECURE` | no | `true` for implicit TLS (465); `false` uses STARTTLS (587) |
| `SMTP_USER` / `SMTP_PASS` | together | TLS is required whenever a login is set |
| `PUBLIC_API_URL` | for links | Set in `fly.toml` to `https://tradeiq-backend.fly.dev` |
| `REPORT_LINK_SECRET` | for links | At least 32 characters. Signs the CSV download links. Rotating it revokes every link already sent. |

If SMTP is only partly set or malformed, the server still boots. It logs why email is off, and deliveries are recorded as `not_configured`.

At startup the server logs `[report-email] on: …` with the host, port, TLS mode, whether a login is set, and the sender. It never logs the user or password.

## What gets sent

- **Subject:** `TradeIQ report: <report> for <client>, <start> – <end>`
- **Body:** the report, client, period, generated time and row count, all in the client's timezone (`Client.timezone`).
- **CSV:** attached when it is **5 MB or less** (`MAX_CSV_ATTACHMENT_BYTES`; base64 brings that to about 6.7 MB, under SES's 10 MB message limit). Larger reports carry only the download link.
- **Download link:** `GET /report-downloads/:token`, no login needed.
  - The token is HMAC-signed for one tenant, schedule and run, and **expires 7 days** after the run was generated.
  - Expired → 410, tampered → 401, no matching run → 404. Responses are `no-store` and rate-limited per IP.
  - The same link is included in the `report.generated` webhook as `csvDownloadUrl` and `csvDownloadExpiresAt`. Both are null unless `PUBLIC_API_URL` and `REPORT_LINK_SECRET` are set.

## Delivery and retries

- One `report_email_deliveries` row per recipient. They retry like webhook deliveries (1m, 5m, 25m, 2h, 6h) and give up after 6 attempts.
- If SMTP is removed while rows are queued, those rows give up with the reason instead of retrying forever.
- Recipients must be 1–50 valid email addresses. Older schedules holding other strings still run; the invalid entries are skipped and named in the run outcome.
- Delivery log: `GET /report-schedules/:id/runs/:runId/email-deliveries` (manager/admin, tenant-scoped).

## Configure on Fly

Signed links:

```sh
fly secrets set -a tradeiq-backend REPORT_LINK_SECRET="$(openssl rand -base64 48)"
```

**Google Workspace:** the sending mailbox needs 2-Step Verification and an app password.

```sh
fly secrets set -a tradeiq-backend \
  SMTP_HOST="smtp.gmail.com" SMTP_PORT="465" SMTP_SECURE="true" \
  SMTP_USER="<reports@yourdomain.com>" SMTP_PASS="<app password>" \
  SMTP_FROM="TradeIQ Reports <reports@yourdomain.com>"
```

**Amazon SES:** verify the domain, request production access, and create **SES SMTP credentials**. IAM access keys don't work for SMTP.

```sh
fly secrets set -a tradeiq-backend \
  SMTP_HOST="email-smtp.<region>.amazonaws.com" SMTP_PORT="587" SMTP_SECURE="false" \
  SMTP_USER="<SES SMTP username>" SMTP_PASS="<SES SMTP password>" \
  SMTP_FROM="TradeIQ Reports <reports@yourdomain.com>"
```

`fly secrets set` restarts the machines. To switch email off again, unset the SMTP variables:

```sh
fly secrets unset -a tradeiq-backend SMTP_HOST SMTP_PORT SMTP_SECURE SMTP_USER SMTP_PASS SMTP_FROM
```

## Test it

1. Run `fly logs -a tradeiq-backend` and look for `[report-email] on: …`.
2. In the manager console, open a report schedule that includes your own address and use **Run now**.
3. Check the email arrived, with the CSV attached or a link, and that the link downloads.
4. If it didn't arrive, read the run's delivery log: `GET /report-schedules/:id/runs/:runId/email-deliveries`.

Locally, point the `SMTP_*` variables at a test inbox such as Mailpit or MailHog (`SMTP_HOST=localhost SMTP_PORT=1025 SMTP_SECURE=false`, no login).
