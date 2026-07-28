import * as dotenv from 'dotenv';
import * as path from 'path';
import { workerDatabaseUrl } from './jest.worker-db';

dotenv.config({ path: path.resolve(__dirname, '.env.test'), override: true });

// Point this worker at its own database (#186). `jest.global-setup.ts` has
// already created one per worker. JEST_WORKER_ID is '1' even under
// --runInBand, so the serial path uses tradeiq_test_1 like any other worker
// rather than needing a special case.
const baseUrl = process.env.DATABASE_URL;
if (!baseUrl) {
  throw new Error('DATABASE_URL not set after loading .env.test');
}
process.env.DATABASE_URL = workerDatabaseUrl(baseUrl, process.env.JEST_WORKER_ID ?? '1');
