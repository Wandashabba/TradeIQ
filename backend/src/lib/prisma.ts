import { PrismaClient } from '@prisma/client';

// passwordHash never leaves the DB layer unless a call site explicitly opts in
// (see authenticateUser). This makes credential disclosure a compile error
// rather than something every author must remember to allowlist.
//
// A photo's duplicate-detection hashes (#244) are omitted the same way. They are
// fraud-engine internals: returning them from POST/GET /photos would tell the
// field app exactly what the duplicate_photo signal compares. The fraud service
// selects them explicitly.
export const prisma = new PrismaClient({
  omit: {
    user: { passwordHash: true },
    photo: { contentHash: true, perceptualHash: true, perceptualHashBands: true },
  },
});
