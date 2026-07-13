import { createHmac } from 'node:crypto';
import { signWebhookBody } from './webhooks.service';

// Pure signing tests — no DB, no network. The dispatch path itself is
// fire-and-forget over `fetch` and is exercised by the routes test.
describe('signWebhookBody (#38)', () => {
  const secret = 'whsec_abc123';
  const timestamp = '2026-07-13T09:00:00.000Z';
  const body = JSON.stringify({ event: 'alert.raised', payload: { id: 'a1' } });

  it('produces an HMAC-SHA256 of <timestamp>.<body>', () => {
    const expected = createHmac('sha256', secret)
      .update(`${timestamp}.${body}`)
      .digest('hex');

    expect(signWebhookBody(secret, timestamp, body)).toBe(expected);
  });

  it('is deterministic for the same inputs', () => {
    expect(signWebhookBody(secret, timestamp, body)).toBe(
      signWebhookBody(secret, timestamp, body),
    );
  });

  it('changes when the body changes — a tampered payload cannot keep its signature', () => {
    const tampered = JSON.stringify({ event: 'alert.raised', payload: { id: 'a2' } });

    expect(signWebhookBody(secret, timestamp, tampered)).not.toBe(
      signWebhookBody(secret, timestamp, body),
    );
  });

  it('changes when the timestamp changes — a captured payload cannot be replayed', () => {
    // The timestamp is signed *with* the body, not merely sent beside it. An
    // attacker who captures a delivery cannot re-send it with a fresh timestamp
    // and still present a valid signature.
    expect(signWebhookBody(secret, '2026-07-14T09:00:00.000Z', body)).not.toBe(
      signWebhookBody(secret, timestamp, body),
    );
  });

  it('changes with the secret — one subscriber cannot forge another’s delivery', () => {
    expect(signWebhookBody('whsec_other', timestamp, body)).not.toBe(
      signWebhookBody(secret, timestamp, body),
    );
  });
});
