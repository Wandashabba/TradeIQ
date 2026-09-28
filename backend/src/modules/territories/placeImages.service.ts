import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

/**
 * THE PICTURE OF THE PLACE IN SCOPE.
 *
 * The Floor's plate carries a view of the territory the manager has filtered
 * to — a street in Tshwane, a forecourt on the East Rand, the Winelands — and
 * it changes when they change the filter. This is where those bytes come from.
 *
 * ## It is not evidence, and this module is where that is enforced
 *
 * A place image lives in `place_images`, which has no `visitId`, no GPS tag and
 * no capture time. Nothing here reads or writes `photos`, and nothing that
 * reads `photos` can reach this table. That separation is the whole point: a
 * picture above a list of shelf decisions must not be mistakable for a reading
 * of one of them.
 *
 * Every row today is `source: 'generated'` — made once by
 * `scripts/generate-place-images.ts`, committed, and loaded off disk by the
 * seed. The marker leaves with the bytes (`X-Image-Source`) so the client can
 * say so out loud rather than assume.
 */

/** What a place image is stored as: `data:<mime>;base64,…`. */
const DATA_URL = /^data:([^;,]+);base64,(.+)$/s;

export interface PlaceImageBytes {
  contentType: string;
  bytes: Buffer;
  /** `generated` today. Echoed to the client, never inferred there. */
  source: string;
  /** The model that made it, when one did. */
  generator: string | null;
}

/**
 * Thrown when the stored row exists but its `url` is not a decodable data URL.
 *
 * A 422 rather than a 404, exactly as `photos` does for the same condition: the
 * request was fine and the row is broken, and saying "not found" would send
 * whoever is debugging it to look for a missing record.
 */
export class PlaceImageSourceError extends Error {}

/**
 * The image for one scope, or [NotFoundError] when that scope has none.
 *
 * `territoryId: null` is the client's whole footprint — the picture The Floor
 * shows under "All territories". It is a real, separately generated image and
 * not one province standing in for the country.
 *
 * A missing row is a 404 and the client draws its designed no-picture state.
 * Nothing is invented to fill the hole.
 */
export async function getPlaceImage(
  clientId: string,
  territoryId: string | null,
): Promise<PlaceImageBytes> {
  const row = await prisma.placeImage.findFirst({
    // clientId is in the predicate and not merely on the row: a territory id
    // from another tenant must miss, not leak a picture of somewhere it names.
    where: { clientId, territoryId },
    select: { url: true, mimeType: true, source: true, generator: true },
  });
  if (!row) throw new NotFoundError('No picture of this place');

  const match = DATA_URL.exec(row.url);
  if (!match) {
    throw new PlaceImageSourceError('The stored place image is not a base64 data URL');
  }
  const bytes = Buffer.from(match[2]!, 'base64');
  if (bytes.length === 0) {
    throw new PlaceImageSourceError('The stored place image decodes to no bytes');
  }

  return {
    contentType: match[1] ?? row.mimeType,
    bytes,
    source: row.source,
    generator: row.generator,
  };
}
