# Competitor shelf prices from retailer websites

TradeIQ can read competitor shelf prices from South African retailers' public
websites (Checkers, Pick n Pay, Shoprite, Makro, Woolworths and so on), store
them, and let Ask TradeIQ answer questions about them with
`getCompetitorShelfPrices`.

**It ships switched off, and it stays off until the legal checklist below is
signed off.** Most retailers' terms of use restrict automated access to their
sites. This feature is built to be compliant where collection is allowed, but
"built compliantly" does not make it allowed.

**No request has ever been sent to a retailer's website from this code**,
including while it was being built and tested. The one implemented adapter
points at a reserved `.test` domain and is tested against local fixture pages.
Every real retailer adapter is a stub.

This page is for whoever operates the feature and answers for it. It covers the
gate, the legal checklist, how to switch it on for a client, how collection
behaves, and how to add an adapter.

---

## The gate

Collection runs, and the assistant tool is declared, only when **all** of these
are true:

| # | Condition | Where | Default |
|---|---|---|---|
| 1 | `COMPETITOR_PRICE_COLLECTION=on` (the global kill switch) | environment | `off` |
| 2 | `competitorPriceCollectionEnabled` is true | `clients` row | `false` |
| 3 | `competitorPriceCollectionApprovedBy` **and** `competitorPriceCollectionApprovedAt` are both set | `clients` row | null |

- **The kill switch overrides everything.** Anything other than the exact word
  `on` counts as off: unset, `true`, `yes`, a typo. When it is off:
  - the scheduled job is never started (`server.ts`);
  - a collection run returns before it touches the database or the network;
  - `getCompetitorShelfPrices` is not declared to the model, and the gate check
    does not even query the database.
- **A client's own switch can only be turned on through the admin endpoint**,
  which requires both approval fields and writes an audit row in the same
  transaction.
- **Switching off clears the approval.** Switching back on needs a new
  approval. The earlier one stays in the audit ledger.
- **The gate is checked again during a run**, before each request. Turning a
  client off stops a run in progress at the next product, not at the end.
- **The tool checks the gate again when it runs**, so a roster built before the
  switch was turned off cannot return data afterwards.

Code: `backend/src/modules/competitorPrices/gate.ts`,
`backend/src/modules/assistant/toolGates.ts`.

---

## Legal checklist (before switching anything on)

Work through this per retailer, and record the outcome (who, when, reference)
in the approval `note`. The approver named in `approvedBy` should be the person
who signed off the legal review, normally counsel.

### 1. Terms of use
- [ ] Read the retailer's current website terms of use and any separate
      "acceptable use", "API" or "data" terms.
- [ ] Check whether they prohibit automated access, scraping, crawling,
      extraction, or commercial reuse of prices. Many do.
- [ ] If they prohibit it: **do not collect.** Ask the retailer for written
      permission, or for an official feed or API (see 2). The stub stays a stub.
- [ ] Record the version or date of the terms that were reviewed.

### 2. Official feeds and APIs first
- [ ] Ask whether the retailer offers a product feed, affiliate feed, or partner
      API that covers price. If one exists and its terms allow this use, build
      the adapter's `officialFeed` and use that instead of reading pages.

### 3. robots.txt
- [ ] Read `https://<retailer>/robots.txt` **by hand** (in a browser, as a
      person) and note what it says for `*` and for any named bots.
- [ ] The collector also enforces it on every request (see "How collection
      behaves"). That is a floor, not the review. A site whose robots.txt
      allows a path can still forbid scraping in its terms.

### 4. POPIA
- [ ] Confirm the adapter collects only the fields listed below. None of them
      is personal information, so POPIA is **not implicated** by the data
      collected. That holds only while the whitelist holds: reviews, reviewer
      names, Q&A and seller contact details must never be added.
- [ ] Note that the bot's User-Agent carries a TradeIQ contact
      (`COMPETITOR_PRICE_BOT_CONTACT`), which is a business contact, not the
      data subject of anything collected.

### 5. Competition Act (Act 89 of 1998)
Collecting a competitor's **public** retail price for your own pricing decisions
is ordinarily lawful. The risk is in what happens next:
- [ ] **Do not share collected competitor prices between competing clients.**
      Observations and mappings are tenant-scoped in the database, and must
      stay that way. A TradeIQ service that pooled or relayed competitors'
      pricing between rival suppliers could facilitate information exchange or
      price co-ordination between competitors (section 4(1)(b)).
- [ ] Do not use the data to agree, signal or align prices with a competitor,
      or to monitor adherence to a resale price (section 5(2) prohibits
      minimum resale price maintenance).
- [ ] If two TradeIQ clients compete in the same category, get legal advice
      before enabling both. The code keeps their data apart; the Commission
      will look at what the service as a whole makes possible.
- [ ] Keep the audit trail: who approved it, when, and on what basis.

### 6. Operational commitments
- [ ] A named person monitors `competitor_price_collection_events` for `blocked`
      and `robots_disallowed`, and stops mapping a retailer that has blocked us
      rather than working around it.
- [ ] The contact address in the User-Agent is monitored, and a request from a
      retailer to stop is honoured the same day, by turning the client switch
      off and/or deactivating that retailer's mappings.

---

## What is collected

For each mapped product page: **product name, pack size, regular shelf price,
promo price and promo end date if the page shows them, the URL, and when it was
read.** Nothing else. No reviews, no ratings, no reviewer or seller details, no
stock levels, no images, no personal data.

Observations are **append-only** (a database trigger refuses `UPDATE`): a price
that changed is a new row, so the table is the history. The approval audit
ledger is append-only in the same way.

### Mapping, not matching
Only products an **admin has mapped by hand** are collected. A mapping says
"this retailer product page is this competitor SKU", optionally "which competes
with this product of ours". Nothing matches products automatically. A fuzzy
match presented as fact could put a wrong competitor price in front of a pricing
decision. Mappings are per client, and they are deactivated rather than deleted.

---

## Switching it on for a client

All endpoints are **admin only** and scoped to the admin's own client.

1. Complete the legal checklist for the retailers involved.
2. Set the environment on **one** API instance (see "One instance" below):

   ```
   COMPETITOR_PRICE_COLLECTION=on
   COMPETITOR_PRICE_BOT_CONTACT=https://tradeiq.example/bot   # or mailto:ops@...
   ```

   Collection refuses to send anything without a contact.
3. Record the approval:

   ```http
   POST /competitor-prices/settings/enable
   Authorization: Bearer <admin token>
   Content-Type: application/json

   {
     "approvedBy": "A. Counsel, Legal",
     "approvedAt": "2026-10-01T09:00:00Z",
     "note": "ToU review for Checkers, ref LEG-123; robots.txt read 2026-09-30"
   }
   ```

   Both `approvedBy` and `approvedAt` are required; `approvedAt` cannot be in
   the future. The response reports `active` and `inactiveReason`, so it shows
   when the kill switch is still off.
4. Map products:

   ```http
   GET  /competitor-prices/retailers          # ids, status (implemented/stub)
   POST /competitor-prices/mappings
   { "competitorSku": "Coca-Cola 2L", "competitorBrand": "Coca-Cola",
     "retailer": "checkers", "productUrl": "https://www.checkers.co.za/.../p/...",
     "packSize": "2L", "ourSkuId": "<one of our SKU ids>" }
   PATCH /competitor-prices/mappings/:id      # { "active": false } to stop collecting one
   GET  /competitor-prices/mappings[?includeInactive=true]
   ```

   The URL must be https, on the retailer's own host, and match the adapter's
   product-page pattern. A mapping to a **stub** retailer is accepted, but
   nothing is collected for it until the adapter is implemented.
5. Check `GET /competitor-prices/settings` and `GET /competitor-prices/audit`.

To switch off: `POST /competitor-prices/settings/disable` (optional `note`).
To stop everything for every client at once: set
`COMPETITOR_PRICE_COLLECTION=off` and restart.

---

## How collection behaves

A daily job (`collector.worker.ts`, started only when the kill switch is on)
runs from 01:00 UTC (03:00 SAST). For each client whose gate is open, for each
**active mapping** on an **implemented** adapter, it reads the page once.
Every request goes through `PoliteFetcher`:

| Rule | Detail |
|---|---|
| URL | https only, on the adapter's own hosts, no credentials or ports. Redirects are followed only on the same hosts, at most 3. |
| robots.txt | Read before any page, parsed per RFC 9309 (groups, longest match, `*` and `$`), cached 24 hours. A disallowed path is refused and recorded as `robots_disallowed`. A 404 robots.txt means no restrictions. A 401/403/429 means blocked. A 5xx, redirect or network error means complete disallow, re-checked after 1 hour. |
| Identity | `User-Agent: TradeIQPriceBot/1.0 (+<contact>; competitor shelf-price research for TradeIQ; honours robots.txt)`. No browser string, no cookies, no login. |
| Spacing | At least 10 s between requests to one domain (`COMPETITOR_PRICE_DOMAIN_INTERVAL_MS`, default 15 s, cannot go lower), plus a global gap (`COMPETITOR_PRICE_GLOBAL_INTERVAL_MS`, default 3 s). A robots.txt `Crawl-delay` longer than that is honoured. |
| Daily cap | `COMPETITOR_PRICE_DAILY_CAP` requests per domain per UTC day (default 50, max 200), robots.txt included. |
| Retries | Only a 5xx or network error, with exponential backoff, at most 3 attempts. |
| Blocks | A 401, 403 or 429, or a captcha/bot-wall page (at any status), stops all requests to that retailer. It is recorded as `blocked` and not retried: for 14 days no client's run asks that retailer again. |
| Never | Login, captcha solving, proxy or IP rotation, rotating or faked User-Agents, headless browsers, or any other evasion. If a site blocks, we stop. |

Everything that was not a price (refusals, blocks, parse failures, caps, stub
adapters) is written to `competitor_price_collection_events`.

**One instance.** Spacing, caps and the "once a day" marker are held in memory
per process. Run with the kill switch on in exactly one instance.

---

## What the assistant says

`getCompetitorShelfPrices` is declared only when the gate is open. For each
mapped competitor SKU it returns, per retailer: the latest shelf and promo
price, the trend over `trendDays` (default 30), and the gap to our own price.
Our price is our agents' average captured shelf price over the last 30 days, or
our RRP when there is none, and the result says which.

- Every figure carries **provenance**: retailer, URL, domain, retrieved-at, and
  `origin: outside_public_retailer_website`. The result also has a `sources`
  list in the same shape as web-search citations (`title`, `url`, `domain`,
  `pageAge`, `retrievedAt`, `snippet`).
- A price older than `COMPETITOR_PRICE_STALE_DAYS` (default 7) is marked
  `stale`, labelled "STALE: … not a current price", and no gap is computed from
  it.
- Its description sends competitor sightings from store visits to
  `getCompetitorActivity`, and our own prices against RRP to
  `getPriceCompliance`.

---

## Adding an adapter

Adapters live in `backend/src/modules/competitorPrices/adapters/`. An adapter
is configuration plus a parser. It never sends a request itself, so it cannot
opt out of the rules above.

1. **Legal first.** Complete the checklist for this retailer. Without sign-off,
   leave it a stub.
2. **Feed or page?** If the retailer offers a feed or API that allows this use,
   implement `officialFeed.fetchPrice(productUrl, fetcher)`. It must use the
   `fetcher` it is given, so robots.txt, spacing, caps and block handling still
   apply. The collector prefers it over pages.
3. **Confirm the URLs by hand.** As a person in a browser, confirm the host(s),
   the product-page URL pattern and the search URL. Replace the stub's
   placeholder `productUrlPattern` and `searchPath`. The search URL is only for
   admins looking up a product page to map. It is never used to match products.
4. **Save a fixture.** Save one product page, and one promo page if possible,
   under `__fixtures__/`, with anything that is not needed for the test
   removed. Also check the saved page's own terms allow keeping a copy for
   testing.
5. **Write the parser** against the fixture. Prefer the page's schema.org
   `Product` JSON-LD (`parseSchemaOrgProduct`) when it is present. Return only
   `productName`, `packSize`, `shelfPrice`, `promoPrice` and `promoEndsAt`.
   Throw `ShelfPriceParseError` rather than guessing. Refuse a page with more
   than one product.
6. **Set `status: 'implemented'`**, and add tests like `adapters.test.ts`: the
   fixture parses, promo semantics hold, and nothing outside the whitelist
   comes back.
7. **Never test against the live site.** Tests use a scripted `fetch`, and the
   collector tests fail if the global `fetch` is called at all.

The shipped adapters:

| id | Status | Notes |
|---|---|---|
| `example` | implemented, **fixture-only** | `shop.example.test` (reserved, never resolves). Reads schema.org JSON-LD. Exercised only by tests; the collector skips it outside them and the mapping API rejects it. |
| `checkers` | stub | TODO: legal review, feed enquiry, confirm URL patterns, parser + fixture |
| `picknpay` | stub | same |
| `shoprite` | stub | same |
| `makro` | stub | same |
| `woolworths` | stub | same |
