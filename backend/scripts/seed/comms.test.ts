import { USERS } from './catalog';
import { buildComms } from './comms';

const ANCHOR = new Date('2026-07-28T00:00:00.000Z');
const COMMS = buildComms({ anchor: ANCHOR, users: USERS });

describe('buildComms', () => {
  it('produces message threads and announcements', () => {
    expect(COMMS.messages.length).toBeGreaterThan(0);
    expect(COMMS.announcements.length).toBeGreaterThan(0);
  });

  it('has both read and unread messages, so the badge is not always zero', () => {
    expect(COMMS.messages.some((m) => m.readAt === null)).toBe(true);
    expect(COMMS.messages.some((m) => m.readAt !== null)).toBe(true);
  });

  it('only ever references real users', () => {
    const ids = new Set(USERS.map((u) => u.id));
    for (const message of COMMS.messages) {
      expect(ids.has(message.senderId)).toBe(true);
      if (message.recipientId !== null) expect(ids.has(message.recipientId)).toBe(true);
    }
    for (const announcement of COMMS.announcements) {
      expect(ids.has(announcement.authorId)).toBe(true);
    }
  });

  it('never dates a message in the future', () => {
    for (const message of COMMS.messages) {
      expect(message.createdAt.getTime()).toBeLessThanOrEqual(ANCHOR.getTime());
    }
  });

  it('is authored by managers, addressed to agents', () => {
    const managerIds = new Set(USERS.filter((u) => u.role === 'manager').map((u) => u.id));
    expect(COMMS.announcements.every((a) => managerIds.has(a.authorId))).toBe(true);
  });

  it('is deterministic', () => {
    const again = buildComms({ anchor: ANCHOR, users: USERS });
    expect(again.messages.map((m) => m.body)).toEqual(COMMS.messages.map((m) => m.body));
  });
});
