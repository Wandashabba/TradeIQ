import { Router } from 'express';
import { authenticateUser, issueToken } from './auth.service';

export const authRouter = Router();

authRouter.post('/login', async (req, res) => {
  const { email, password } = req.body as { email?: string; password?: string };
  if (!email || !password) {
    res.status(400).json({ error: 'email and password are required' });
    return;
  }

  const user = await authenticateUser(email, password);
  if (!user) {
    res.status(401).json({ error: 'Invalid credentials' });
    return;
  }

  const token = issueToken({ userId: user.id, role: user.role, clientId: user.clientId });
  res.status(200).json({ token, role: user.role });
});
