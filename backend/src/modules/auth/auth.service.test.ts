import { issueToken, verifyToken } from './auth.service';

describe('auth.service', () => {
  const payload = { userId: 'user-1', role: 'field_agent' as const, clientId: 'client-1' };

  it('issues a token that verifies back to the same payload', () => {
    const token = issueToken(payload);
    const decoded = verifyToken(token);
    expect(decoded.userId).toBe(payload.userId);
    expect(decoded.role).toBe(payload.role);
    expect(decoded.clientId).toBe(payload.clientId);
  });

  it('throws when verifying a malformed token', () => {
    expect(() => verifyToken('not-a-real-token')).toThrow();
  });
});
