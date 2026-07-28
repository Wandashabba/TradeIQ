import { addDays, addHours } from './calendar';
import { UserSeed } from './catalog';
import { makeRng, pick } from './rng';

/** Manager-to-agent messages and company announcements (Phase 3 #37). */

export interface GeneratedMessage {
  id: string;
  senderId: string;
  recipientId: string | null;
  body: string;
  readAt: Date | null;
  createdAt: Date;
}

export interface GeneratedAnnouncement {
  id: string;
  authorId: string;
  title: string;
  body: string;
  createdAt: Date;
}

export interface CommsBundle {
  messages: GeneratedMessage[];
  announcements: GeneratedAnnouncement[];
}

const MESSAGE_BODIES = [
  'Morning — please prioritise the end-cap rebuild at your first two stops today.',
  'Thanks for closing the price tags at Sandton, the photo came through clearly.',
  'Heads up: the promo POSM shipment lands Thursday, hold the wobblers until then.',
  'Your scorecard average is up 6 points this month. Nicely done.',
  'Can you re-check the back-stock at the Fourways store? Numbers look off.',
  'Please confirm you have the updated planogram before your Wednesday run.',
];

const ANNOUNCEMENTS = [
  {
    title: 'Q3 Perfect Store push is live',
    body: 'Every store scored 80 or above this quarter earns the team an R500 airtime voucher. Photograph every end-cap rebuild — verified closures are what count.',
  },
  {
    title: 'New planogram effective Monday',
    body: 'The revised carbonates planogram moves the 2L range to eye level. Download it in the app before your first call and flag any store that cannot comply.',
  },
];

export function buildComms(input: { anchor: Date; users: UserSeed[] }): CommsBundle {
  const { anchor, users } = input;
  const rng = makeRng(31415926);

  const managers = users.filter((u) => u.role === 'manager');
  const agents = users.filter((u) => u.role === 'field_agent');

  const messages: GeneratedMessage[] = MESSAGE_BODIES.map((body, index) => ({
    id: `demo-message-${index + 1}`,
    senderId: pick(rng, managers).id,
    recipientId: pick(rng, agents).id,
    body,
    // The two most recent stay unread so the badge is non-zero in a demo.
    readAt: index < MESSAGE_BODIES.length - 2 ? addHours(anchor, -index * 6) : null,
    createdAt: addHours(addDays(anchor, -index), -index * 3),
  }));

  const announcements: GeneratedAnnouncement[] = ANNOUNCEMENTS.map((entry, index) => ({
    id: `demo-announcement-${index + 1}`,
    authorId: pick(rng, managers).id,
    title: entry.title,
    body: entry.body,
    createdAt: addDays(anchor, -(index * 5 + 2)),
  }));

  return { messages, announcements };
}
