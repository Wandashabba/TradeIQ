import 'dotenv/config';
import { randomBytes, randomUUID } from 'crypto';
import { Prisma } from '@prisma/client';
import { prisma } from '../../src/lib/prisma';
import { perceptualHashBands } from '../../src/modules/photos/photoHash';
import { assertBenchDatabase, intFlag } from './benchDb';

/**
 * Benchmark seed for the duplicate-photo lookups (#311). NOT run in CI, and
 * never against a real database: it refuses unless DATABASE_URL names a
 * database whose name contains "bench".
 *
 *   # an empty, migrated scratch database
 *   DATABASE_URL=.../tradeiq_bench311 npx prisma migrate deploy
 *   npx ts-node scripts/bench/seed-duplicate-photos.ts --photos 50000
 *   npx ts-node scripts/bench/explain-duplicate-photo.ts
 *
 *   --photos   audit photos to write, roughly (default 50000)
 *   --outlets  outlets across all clients (default 2000)
 *   --clients  tenants (default 3)
 *   --seed     PRNG seed (default 311)
 *
 * What it writes, per client, in visit order (device checkinTs ascending):
 *   - ~5 audit photos per submitted visit (4-6), `url` a tiny placeholder —
 *     the lookups never read `url`, and real base64 would only bloat the heap;
 *   - contentHash: random SHA-256-shaped hex; perceptualHash: random 64 bits;
 *     perceptualHashBands from perceptualHashBands() in photos/photoHash.ts, so
 *     the stored keys are exactly what POST /photos stores;
 *   - ~1.5% exact re-uploads of an EARLIER photo (same content + perceptual
 *     hash), mostly at another outlet;
 *   - ~1.5% near-duplicates of an earlier photo: 1-6 dHash bits flipped, new
 *     content hash;
 *   - ~0.3% a per-client placeholder image (one hot content hash);
 *   - ~0.5% cross-tenant copies of another client's photo (must never match);
 *   - ~1% degenerate (near-blank) perceptual hashes, which get no bands;
 *   - ~2% rows with no hashes at all (uploaded before #244, not backfilled);
 *   - a task_closure photo on ~8% of visits, half of them byte-identical to an
 *     audit photo (must never match, on either side).
 * Everything is written with batched `INSERT ... SELECT unnest(...)`, then
 * ANALYZEd.
 */

const TASK_CLOSURE = 'task_closure';
const AUDIT_SECTIONS = ['shelf', 'visibility', 'pricing', 'competitive', 'stock'];
const INSERT_BATCH = 5000;
const DAY_MS = 24 * 60 * 60 * 1000;

/** mulberry32: small, fast, deterministic. */
function makeRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

interface PhotoRow {
  id: string;
  visitId: string;
  clientId: string;
  agentId: string;
  section: string;
  timestamp: Date;
  contentHash: string | null;
  perceptualHash: string | null;
}

interface VisitRow {
  id: string;
  clientId: string;
  outletId: string;
  agentId: string;
  checkinTs: Date;
}

async function insertInBatches<T>(rows: T[], insert: (batch: T[]) => Promise<unknown>): Promise<void> {
  for (let i = 0; i < rows.length; i += INSERT_BATCH) {
    await insert(rows.slice(i, i + INSERT_BATCH));
  }
}

async function main(): Promise<void> {
  assertBenchDatabase();
  const targetPhotos = intFlag('photos', 50000);
  const outletCount = intFlag('outlets', 2000);
  const clientCount = intFlag('clients', 3);
  const rng = makeRng(intFlag('seed', 311));
  const pick = <T>(items: T[]): T => items[Math.floor(rng() * items.length)];
  const hex64 = (): string => {
    const hi = Math.floor(rng() * 0x100000000);
    const lo = Math.floor(rng() * 0x100000000);
    return hi.toString(16).padStart(8, '0') + lo.toString(16).padStart(8, '0');
  };
  const flipBits = (hex: string, flips: number): string => {
    let value = BigInt(`0x${hex}`);
    const used = new Set<number>();
    while (used.size < flips) {
      used.add(Math.floor(rng() * 64));
    }
    for (const bit of used) {
      value ^= 1n << BigInt(bit);
    }
    return value.toString(16).padStart(16, '0');
  };
  const sha = (): string => randomBytes(32).toString('hex');

  const existing = await prisma.photo.count();
  if (existing > 0) {
    throw new Error(`photos already has ${existing} rows; seed an empty, freshly migrated bench database`);
  }

  const started = Date.now();
  const clients: Array<{ id: string; name: string }> = Array.from({ length: clientCount }, (_, i) => ({
    id: randomUUID(),
    name: `Bench client ${i}`,
  }));
  const territories = clients.map((c) => ({ id: randomUUID(), clientId: c.id }));
  const agentsByClient = new Map(clients.map((c) => [c.id, Array.from({ length: 30 }, () => randomUUID())]));
  const outlets = Array.from({ length: outletCount }, (_, i) => {
    const territory = territories[i % clientCount];
    return { id: randomUUID(), clientId: territory.clientId, territoryId: territory.id, code: `B${i}` };
  });

  for (const c of clients) {
    await prisma.$executeRaw`
      INSERT INTO clients (id, name, industry, scorecard_weights, kpi_thresholds)
      VALUES (${c.id}, ${c.name}, 'fmcg', '{}'::jsonb, '{}'::jsonb)`;
  }
  for (const t of territories) {
    await prisma.$executeRaw`
      INSERT INTO territories (id, client_id, name, code) VALUES (${t.id}, ${t.clientId}, 'Bench', 'BENCH')`;
  }
  const agents = clients.flatMap((c) => (agentsByClient.get(c.id) ?? []).map((id) => ({ id, clientId: c.id })));
  await prisma.$executeRaw`
    INSERT INTO users (id, email, password_hash, role, client_id)
    SELECT id, 'bench-' || id || '@example.test', 'x', 'field_agent'::"UserRole", client_id
    FROM unnest(${agents.map((a) => a.id)}::text[], ${agents.map((a) => a.clientId)}::text[]) AS u(id, client_id)`;
  await prisma.$executeRaw`
    INSERT INTO outlets (id, name, code, channel_type, lat, lng, territory_id, client_id)
    SELECT id, 'Bench outlet ' || code, code, 'general_trade', -26.2, 28.04, territory_id, client_id
    FROM unnest(
      ${outlets.map((o) => o.id)}::text[], ${outlets.map((o) => o.code)}::text[],
      ${outlets.map((o) => o.territoryId)}::text[], ${outlets.map((o) => o.clientId)}::text[]
    ) AS o(id, code, territory_id, client_id)`;

  // Visits first, in checkin order, so "an earlier photo" is simply one already
  // generated for the same client.
  const visitCount = Math.ceil(targetPhotos / 5);
  const horizonStart = Date.now() - 180 * DAY_MS;
  const visits: VisitRow[] = Array.from({ length: visitCount }, () => {
    const outlet = pick(outlets);
    return {
      id: randomUUID(),
      clientId: outlet.clientId,
      outletId: outlet.id,
      agentId: pick(agentsByClient.get(outlet.clientId) ?? []),
      checkinTs: new Date(horizonStart + Math.floor(rng() * 180 * DAY_MS)),
    };
  }).sort((a, b) => a.checkinTs.getTime() - b.checkinTs.getTime());

  const photos: PhotoRow[] = [];
  const auditByClient = new Map<string, PhotoRow[]>(clients.map((c) => [c.id, []]));
  const placeholder = new Map(clients.map((c) => [c.id, { contentHash: sha(), perceptualHash: hex64() }]));
  const counts = { exact: 0, near: 0, placeholder: 0, crossTenant: 0, degenerate: 0, unhashed: 0, closure: 0 };

  for (const visit of visits) {
    const earlier = auditByClient.get(visit.clientId) ?? [];
    const photoCount = 4 + Math.floor(rng() * 3);
    for (let n = 0; n < photoCount; n += 1) {
      let contentHash: string | null = sha();
      let perceptualHash: string | null = hex64();
      const roll = rng();
      if (roll < 0.015 && earlier.length > 0) {
        const source = pick(earlier);
        contentHash = source.contentHash;
        perceptualHash = source.perceptualHash;
        counts.exact += 1;
      } else if (roll < 0.03 && earlier.length > 0) {
        const source = pick(earlier);
        if (source.perceptualHash) {
          perceptualHash = flipBits(source.perceptualHash, 1 + Math.floor(rng() * 6));
          counts.near += 1;
        }
      } else if (roll < 0.033) {
        ({ contentHash, perceptualHash } = placeholder.get(visit.clientId) ?? { contentHash, perceptualHash });
        counts.placeholder += 1;
      } else if (roll < 0.038) {
        const other = auditByClient.get(pick(clients.filter((c) => c.id !== visit.clientId)).id) ?? [];
        if (other.length > 0) {
          const source = pick(other);
          contentHash = source.contentHash;
          perceptualHash = source.perceptualHash;
          counts.crossTenant += 1;
        }
      } else if (roll < 0.048) {
        // Few set bits: a covered lens or blank wall.
        perceptualHash = (1n << BigInt(Math.floor(rng() * 64))).toString(16).padStart(16, '0');
        counts.degenerate += 1;
      } else if (roll < 0.068) {
        contentHash = null;
        perceptualHash = null;
        counts.unhashed += 1;
      }
      const row: PhotoRow = {
        id: randomUUID(),
        visitId: visit.id,
        clientId: visit.clientId,
        agentId: visit.agentId,
        section: AUDIT_SECTIONS[n % AUDIT_SECTIONS.length],
        timestamp: new Date(visit.checkinTs.getTime() + (n + 1) * 60_000),
        contentHash,
        perceptualHash,
      };
      photos.push(row);
      if (contentHash !== null) {
        earlier.push(row);
      }
    }
    if (rng() < 0.08) {
      const copyOfAudit = rng() < 0.5 && earlier.length > 0 ? pick(earlier) : null;
      photos.push({
        id: randomUUID(),
        visitId: visit.id,
        clientId: visit.clientId,
        agentId: visit.agentId,
        section: TASK_CLOSURE,
        timestamp: new Date(visit.checkinTs.getTime() + 3 * DAY_MS),
        contentHash: copyOfAudit ? copyOfAudit.contentHash : sha(),
        perceptualHash: copyOfAudit ? copyOfAudit.perceptualHash : hex64(),
      });
      counts.closure += 1;
    }
  }

  await insertInBatches(visits, (batch) =>
    prisma.$executeRaw`
      INSERT INTO visits (id, outlet_id, agent_id, client_id, checkin_ts, checkin_lat, checkin_lng, geofence_pass, status)
      SELECT id, outlet_id, agent_id, client_id, checkin_ts, -26.2, 28.04, true, 'submitted'::"VisitStatus"
      FROM unnest(
        ${batch.map((v) => v.id)}::text[], ${batch.map((v) => v.outletId)}::text[],
        ${batch.map((v) => v.agentId)}::text[], ${batch.map((v) => v.clientId)}::text[],
        ${batch.map((v) => v.checkinTs.toISOString())}::timestamp[]
      ) AS v(id, outlet_id, agent_id, client_id, checkin_ts)`,
  );
  // Bands go in as one array literal per row: unnest() would flatten an int[][].
  await insertInBatches(photos, (batch) =>
    prisma.$executeRaw`
      INSERT INTO photos (id, visit_id, client_id, uploaded_by_id, section, url, gps_tag, timestamp,
        content_hash, perceptual_hash, perceptual_hash_bands)
      SELECT id, visit_id, client_id, uploaded_by_id, section, 'bench://placeholder',
        '{"lat": -26.2, "lng": 28.04}'::jsonb, ts, content_hash, perceptual_hash, bands::int[]
      FROM unnest(
        ${batch.map((p) => p.id)}::text[], ${batch.map((p) => p.visitId)}::text[],
        ${batch.map((p) => p.clientId)}::text[], ${batch.map((p) => p.agentId)}::text[],
        ${batch.map((p) => p.section)}::text[], ${batch.map((p) => p.timestamp.toISOString())}::timestamp[],
        ${batch.map((p) => p.contentHash)}::text[], ${batch.map((p) => p.perceptualHash)}::text[],
        ${batch.map((p) => `{${perceptualHashBands(p.perceptualHash).join(',')}}`)}::text[]
      ) AS p(id, visit_id, client_id, uploaded_by_id, section, ts, content_hash, perceptual_hash, bands)`,
  );
  await prisma.$executeRaw(Prisma.sql`ANALYZE`);

  console.log(
    JSON.stringify(
      {
        clients: clientCount,
        outlets: outletCount,
        visits: visits.length,
        photos: photos.length,
        auditPhotos: photos.length - counts.closure,
        ...counts,
        seconds: Math.round((Date.now() - started) / 100) / 10,
      },
      null,
      2,
    ),
  );
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
