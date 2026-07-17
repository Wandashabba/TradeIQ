import { PrismaClient } from '@prisma/client';

// passwordHash never leaves the DB layer unless a call site explicitly opts in
// (see authenticateUser). This makes credential disclosure a compile error
// rather than something every author must remember to allowlist.
export const prisma = new PrismaClient({
  omit: { user: { passwordHash: true } },
});
