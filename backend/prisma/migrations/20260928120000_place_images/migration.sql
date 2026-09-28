-- A picture of the PLACE in scope, for The Floor's plate.
--
-- The manager's home screen carried a seeded "shelf photo" — four rows of
-- randomly coloured blocks from a PRNG in scripts/seed/photos.ts. It read as
-- noise, and worse than noise: a picture of a shelf directly above a list of
-- shelf decisions is a picture somebody can act on, and that one was not a
-- reading of anything. So the plate now carries a view of the territory
-- currently filtered — a street in Tshwane, a forecourt on the East Rand, the
-- Winelands — and it changes when the filter changes.
--
-- WHY A TABLE AND NOT A COLUMN ON photos
--
-- Every row in `photos` is evidence: visit sections, the review strip, the
-- storefront that settles an outlet-pin dispute. Each carries a visit, a GPS
-- tag and a capture time, and the fraud engine hashes all of them. A place
-- image has none of those, must never acquire them, and must never be returned
-- by a query that is looking for evidence. A separate table makes that
-- structural instead of a `WHERE source <> 'generated'` somebody forgets.
--
-- `source` is NOT NULL on purpose. Today every row is 'generated' — produced
-- once by scripts/generate-place-images.ts against the Gemini image API,
-- committed under backend/assets/places, and loaded from disk by the seed (the
-- seed never calls an API). The marker travels out through the API's
-- X-Image-Source header to a sentence the plate speaks, so nothing downstream
-- can mistake one of these for a photograph somebody took.

-- CreateTable
CREATE TABLE "place_images" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    -- NULL = the client's whole footprint, which is what The Floor shows under
    -- "All territories".
    "territory_id" TEXT,
    "source" TEXT NOT NULL,
    "generator" TEXT,
    "prompt" TEXT,
    "mime_type" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "place_images_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "place_images_client_id_territory_id_key" ON "place_images"("client_id", "territory_id");

-- CreateIndex
-- Postgres treats NULLs as distinct in a unique index, so the constraint above
-- would happily let one client collect a dozen footprint images. This partial
-- index is the one that actually holds "one picture per scope" for the
-- all-territories row. Prisma cannot express it, so it lives here.
CREATE UNIQUE INDEX "place_images_client_id_footprint_key" ON "place_images"("client_id") WHERE "territory_id" IS NULL;

-- AddForeignKey
ALTER TABLE "place_images" ADD CONSTRAINT "place_images_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "place_images" ADD CONSTRAINT "place_images_territory_id_fkey" FOREIGN KEY ("territory_id") REFERENCES "territories"("id") ON DELETE CASCADE ON UPDATE CASCADE;
