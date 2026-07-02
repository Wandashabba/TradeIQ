import express from 'express';
import { authRouter } from './modules/auth/auth.routes';
import { errorHandler } from './middleware/errorHandler';

export const app = express();

app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use('/auth', authRouter);

app.use(errorHandler);
