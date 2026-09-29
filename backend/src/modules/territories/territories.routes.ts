import { Prisma } from '@prisma/client';
import { Response, Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parseIsoInstant } from '../../lib/parseIsoInstant';
import { parsePagination } from '../../lib/pagination';
import {
  assignAgentToTerritory,
  createTerritory,
  getTerritoryCoverage,
  listTerritoriesForClient,
} from './territories.service';
import { getPlaceImage, PlaceImageSourceError } from './placeImages.service';

export const territoriesRouter = Router();
territoriesRouter.use(requireAuth);

/**
 * A PICTURE OF THE PLACE IN SCOPE — for The Floor's plate.
 *
 * Two routes and one handler: `/place-image` is the client's whole footprint,
 * which is what The Floor shows under "All territories", and
 * `/:id/place-image` is one territory. Raw bytes, like `GET /photos/:id/thumbnail`
 * and for the same reason — `Image.network` cannot carry a bearer token on web,
 * so the app fetches image bytes through its authed client.
 *
 * `X-Image-Source` leaves with every one of them, carrying the row's own value
 * and never a default. It is `generated` for a picture
 * `scripts/generate-place-images.ts` made from a prompt and `supplied` for a
 * photograph the owner handed over, which `scripts/import-place-images.ts`
 * brought in; both are committed seed fixtures. The header is what lets the app
 * say which one it is in the plate's spoken label instead of assuming, and it
 * is why a place image can never be quietly read as a capture — nor a real
 * photograph quietly described as a drawing.
 *
 * 404 when the scope has no picture. The client then draws its designed
 * no-picture state — a drawing that is visibly a drawing, and a sentence.
 * Nothing is substituted.
 */
async function sendPlaceImage(req: AuthedRequest, res: Response, territoryId: string | null) {
  let image;
  try {
    image = await getPlaceImage(req.user!.clientId, territoryId);
  } catch (err) {
    if (err instanceof PlaceImageSourceError) {
      // The row is broken, not the request — the same 422 `photos` answers.
      res.status(422).json({ error: err.message });
      return;
    }
    throw err; // NotFoundError falls through to the errorHandler.
  }

  res
    .status(200)
    .set('Content-Type', image.contentType)
    // THE MARK, ON THE WIRE. Exposed to the browser too, so a web build can
    // read it: without `Access-Control-Expose-Headers` a cross-origin fetch
    // sees the bytes and not the fact that they were generated, which is the
    // one thing about them that must never get lost.
    .set('X-Image-Source', image.source)
    .set('Access-Control-Expose-Headers', 'X-Image-Source')
    // private: tenant-scoped bytes must not land in a shared cache.
    //
    // no-cache: STORE IT, BUT ASK FIRST. This URL is stable and its bytes are
    // not — a reseed replaces the picture behind `/territories/:id/place-image`
    // without the address changing. It used to say `max-age=86400, immutable`,
    // and `immutable` (RFC 8246) is a promise that the bytes at this URL will
    // never change, so a browser holding one skips revalidation even on an
    // ordinary reload. On 29 September 2026 that promise cost the owner their
    // own photographs: the import ran, the database held them, this route
    // served them, and the plate still showed yesterday's generated picture,
    // because the browser had a day-old copy it had been told never to
    // question. `immutable` is only ever true of a URL that carries its own
    // version — a content hash in the path — and this one does not.
    //
    // The bandwidth this looks like it gives up, it does not: Express already
    // sends an ETag, so an unchanged image revalidates to a bodiless 304 and
    // the 60 kB stays on the wire exactly once. What changes is that a reseed
    // is visible on the next reload instead of a day later.
    .set('Cache-Control', 'private, no-cache')
    .send(image.bytes);
}

territoriesRouter.get('/place-image', requireRole('manager', 'admin'), async (req: AuthedRequest, res) =>
  sendPlaceImage(req, res, null),
);

territoriesRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { name, code, region } = req.body as {
    name?: unknown;
    code?: unknown;
    region?: unknown;
  };

  if (typeof name !== 'string' || typeof code !== 'string' || (region !== undefined && typeof region !== 'string')) {
    res.status(400).json({ error: 'name and code are required; region must be a string when given' });
    return;
  }

  try {
    const territory = await createTerritory({
      clientId: req.user!.clientId,
      name,
      code,
      region,
    });
    res.status(201).json(territory);
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      res.status(409).json({ error: 'A territory with this code already exists' });
      return;
    }
    throw err;
  }
});

// Gated to match the rest of this router. Territories are a planning
// construct: every route that reads or writes them is manager/admin, and this
// one was open only by omission.
//
// No agent flow loses anything. Its two callers in the app — the outlet form
// and the beat-plan form — are both manager/admin actions at the write end
// (`POST /outlets`, `POST /beatplans`), so an agent reaching either could only
// ever be refused on submit.
territoriesRouter.get('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  const page = await listTerritoriesForClient({ clientId: req.user!.clientId, limit, cursor });
  res.status(200).json(page);
});

territoriesRouter.post('/:id/agents', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { userId } = req.body as { userId?: unknown };

  if (typeof userId !== 'string') {
    res.status(400).json({ error: 'userId is required' });
    return;
  }

  const { id: territoryId } = req.params as { id: string };

  try {
    const assignment = await assignAgentToTerritory({
      territoryId,
      userId,
      clientId: req.user!.clientId,
    });
    res.status(201).json(assignment);
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      res.status(409).json({ error: 'This agent is already assigned to the territory' });
      return;
    }
    throw err;
  }
});

// Coverage exposes per-agent assignment and outlet-level visit data — a
// management view, unlike the plain territory list above. The router's
// requireAuth alone does not scope it; it needs the role guard to stay
// manager/admin.
territoriesRouter.get(
  '/:id/coverage',
  requireRole('manager', 'admin'),
  async (req: AuthedRequest, res) => {
    const { id: territoryId } = req.params as { id: string };
    const { from, to } = req.query as { from?: string; to?: string };

    // Both optional — coverage works over all-time when neither is given.
    // When supplied, each must be a full ISO-8601 instant (see
    // parseIsoInstant): a naive date/datetime would be resolved as UTC or
    // against the server process's `TZ` — either way invisibly to the caller.
    // This is an arbitrary window, not a calendar-day rule, so it stays in
    // instants and does not read `Client.timezone` (#309).
    let fromDate: Date | undefined;
    let toDate: Date | undefined;
    if (from !== undefined) {
      fromDate = parseIsoInstant(from);
      if (fromDate === undefined) {
        res.status(400).json({ error: 'from must be a valid ISO date' });
        return;
      }
    }
    if (to !== undefined) {
      toDate = parseIsoInstant(to);
      if (toDate === undefined) {
        res.status(400).json({ error: 'to must be a valid ISO date' });
        return;
      }
    }

    const coverage = await getTerritoryCoverage(territoryId, req.user!.clientId, fromDate, toDate);
    res.status(200).json(coverage);
  },
);

territoriesRouter.get(
  '/:id/place-image',
  requireRole('manager', 'admin'),
  async (req: AuthedRequest, res) => {
    const { id } = req.params as { id: string };
    await sendPlaceImage(req, res, id);
  },
);
