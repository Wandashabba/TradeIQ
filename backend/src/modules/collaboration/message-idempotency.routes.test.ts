import request from 'supertest';
import sharp from 'sharp';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, userIn } from '../../test-utils/tenants';

/**
 * #308 — `POST /messages` with `clientMessageId`. A send whose response was
 * lost must be retryable: the retry returns the original message instead of a
 * duplicate, or a 409 because its photos are already attached.
 */
describe('POST /messages idempotency (#308)', () => {
  let clientId: string;
  let agentA: TestUser;
  let agentB: TestUser;
  let pngDataUrl: string;
  let keyCounter = 0;

  const key = () => `key-${Date.now()}-${(keyCounter += 1)}`;

  const send = (user: TestUser, body: Record<string, unknown>) =>
    request(app).post('/messages').set('Authorization', `Bearer ${user.token}`).send(body);

  const uploadId = async (user: TestUser): Promise<string> => {
    const res = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ purpose: 'message_attachment', dataUrl: pngDataUrl });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };

  const rowsWithKey = (clientMessageId: string) =>
    prisma.message.count({ where: { clientId, clientMessageId } });

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'MSGIDEM-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    agentA = await userIn(clientId, 'field_agent');
    agentB = await userIn(clientId, 'field_agent');
    const png = await sharp({
      create: { width: 8, height: 8, channels: 3, background: '#224466' },
    })
      .png()
      .toBuffer();
    pngDataUrl = `data:image/png;base64,${png.toString('base64')}`;
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  afterAll(async () => {
    await prisma.message.deleteMany({ where: { clientId } });
    await prisma.photo.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('creates with 201 and returns the key on the message', async () => {
    const clientMessageId = key();
    const res = await send(agentA, { body: 'hello', clientMessageId });

    expect(res.status).toBe(201);
    expect(res.headers['idempotent-replayed']).toBeUndefined();
    expect(res.body.clientMessageId).toBe(clientMessageId);
  });

  it('a retry with the same key returns the ORIGINAL message with 200, not a duplicate', async () => {
    const clientMessageId = key();
    const first = await send(agentA, { body: 'restock done', recipientId: agentB.userId, clientMessageId });
    expect(first.status).toBe(201);

    const retry = await send(agentA, { body: 'restock done', recipientId: agentB.userId, clientMessageId });

    expect(retry.status).toBe(200);
    expect(retry.headers['idempotent-replayed']).toBe('true');
    expect(retry.body).toEqual(first.body);
    expect(await rowsWithKey(clientMessageId)).toBe(1);
  });

  it('a retry of a send with images returns the original instead of 409 (photos already attached)', async () => {
    const photos = [await uploadId(agentA), await uploadId(agentA)];
    const clientMessageId = key();
    const payload = { body: '', attachmentPhotoIds: photos, clientMessageId };

    const first = await send(agentA, payload);
    expect(first.status).toBe(201);

    const retry = await send(agentA, payload);

    expect(retry.status).toBe(200);
    expect(retry.body.id).toBe(first.body.id);
    expect(retry.body.attachments.map((a: { photoId: string }) => a.photoId)).toEqual(photos);
    expect(await rowsWithKey(clientMessageId)).toBe(1);
  });

  it('without a key, a repeat still creates a second message (unchanged behaviour)', async () => {
    const before = await prisma.message.count({ where: { clientId, senderId: agentA.userId } });
    expect((await send(agentA, { body: 'no key' })).status).toBe(201);
    expect((await send(agentA, { body: 'no key' })).status).toBe(201);
    expect(await prisma.message.count({ where: { clientId, senderId: agentA.userId } })).toBe(before + 2);
  });

  it('a different sender with the same key creates a separate message', async () => {
    const clientMessageId = key();
    const fromA = await send(agentA, { body: 'same key', clientMessageId });
    const fromB = await send(agentB, { body: 'same key', clientMessageId });

    expect(fromA.status).toBe(201);
    expect(fromB.status).toBe(201);
    expect(fromB.body.id).not.toBe(fromA.body.id);
    expect(fromB.body.senderId).toBe(agentB.userId);
    expect(await rowsWithKey(clientMessageId)).toBe(2);
  });

  it.each<[string, () => Promise<Record<string, unknown>>]>([
    ['a different body', async () => ({ body: 'edited' })],
    ['a different recipient', async () => ({ recipientId: agentB.userId })],
    ['different attachments', async () => ({ attachmentPhotoIds: [await uploadId(agentA)] })],
  ])('the same key with %s is a 409 and creates nothing', async (_label, change) => {
    const clientMessageId = key();
    const first = await send(agentA, { body: 'original', clientMessageId });
    expect(first.status).toBe(201);

    const res = await send(agentA, { body: 'original', clientMessageId, ...(await change()) });

    expect(res.status).toBe(409);
    expect(res.body.error).toMatch(/clientMessageId was already used for a different message/);
    expect(await rowsWithKey(clientMessageId)).toBe(1);
  });

  it.each([
    ['empty', ''],
    ['too long', 'k'.repeat(129)],
    ['not a string', 42],
    ['containing spaces', 'two words'],
  ])('rejects a clientMessageId that is %s (400)', async (_label, clientMessageId) => {
    const res = await send(agentA, { body: 'hi', clientMessageId });
    expect(res.status).toBe(400);
  });

  it('two concurrent requests with one key create one message; the other gets the original', async () => {
    const photoId = await uploadId(agentA);
    const clientMessageId = key();
    const payload = { body: 'race', attachmentPhotoIds: [photoId], clientMessageId };

    const responses = await Promise.all([1, 2, 3, 4].map(() => send(agentA, payload)));

    const statuses = responses.map((r) => r.status).sort();
    expect(statuses).toEqual([200, 200, 200, 201]);
    expect(new Set(responses.map((r) => r.body.id)).size).toBe(1);
    expect(await rowsWithKey(clientMessageId)).toBe(1);
  });

  it('the race loser that trips the unique index answers with the winner', async () => {
    // Force the interleaving the concurrent test can only hope for: the
    // loser's lookup runs before the winner commits, so it misses, inserts,
    // and hits the (sender_id, client_message_id) unique index.
    const clientMessageId = key();
    const winner = await send(agentA, { body: 'raced', clientMessageId });
    expect(winner.status).toBe(201);

    const realFindFirst = prisma.message.findFirst.bind(prisma.message);
    let calls = 0;
    jest.spyOn(prisma.message, 'findFirst').mockImplementation(((args: Parameters<typeof realFindFirst>[0]) => {
      calls += 1;
      // The replay lookup is the first findFirst on the request; miss it once.
      return calls === 1 ? Promise.resolve(null) : realFindFirst(args);
    }) as unknown as typeof prisma.message.findFirst);
    const createSpy = jest.spyOn(prisma.message, 'create');

    const loser = await send(agentA, { body: 'raced', clientMessageId });

    expect(createSpy).toHaveBeenCalledTimes(1); // it did try to insert
    expect(loser.status).toBe(200);
    expect(loser.body.id).toBe(winner.body.id);
    expect(await rowsWithKey(clientMessageId)).toBe(1);
  });
});
