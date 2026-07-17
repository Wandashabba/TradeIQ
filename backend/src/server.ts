import 'dotenv/config';
import { app } from './app';
import { assertJwtSecretUsable } from './modules/auth/auth.service';

// Fail fast and loudly: a published or weak JWT_SECRET must stop the process
// here, not surface later as unexplainable 401s.
assertJwtSecretUsable();

const port = process.env.PORT ? Number(process.env.PORT) : 4000;

app.listen(port, () => {
  console.log(`TradeIQ backend listening on port ${port}`);
});
