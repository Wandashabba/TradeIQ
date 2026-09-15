import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { ConflictError, NotFoundError, ValidationError } from '../../middleware/errorHandler';
import { buildPage } from '../../lib/pagination';
import { MESSAGE_ATTACHMENT_SECTION, photoLinks } from '../photos/photos.service';

/**
 * The most images one message may carry (#125). Attachments are images only,
 * uploaded through the photo pipeline — see the MessageAttachment model.
 */
export const MAX_MESSAGE_ATTACHMENTS = 4;

// Attachment metadata only. `photo.url` holds the base64 image, and it must
// never ride along in a message response — clients fetch bytes from the
// thumbnail/image links instead.
const messageInclude = {
  attachments: {
    orderBy: { position: 'asc' },
    select: { photoId: true, position: true },
  },
} satisfies Prisma.MessageInclude;

type MessageRow = Prisma.MessageGetPayload<{ include: typeof messageInclude }>;

function toMessageResponse(row: MessageRow) {
  return {
    ...row,
    attachments: row.attachments.map((a) => ({
      photoId: a.photoId,
      position: a.position,
      ...photoLinks(a.photoId),
    })),
  };
}

export interface CreateMessageInput {
  clientId: string;
  senderId: string;
  body: string;
  recipientId?: string;
  /** Photo ids from `POST /photos` with purpose `message_attachment`. */
  attachmentPhotoIds?: string[];
}

/**
 * Rejects attachment ids that the sender may not attach:
 * * more than MAX_MESSAGE_ATTACHMENTS, or the same id twice → 400;
 * * a photo outside the sender's tenant, or uploaded by someone else → 404
 *   (the same answer as a photo that does not exist — an id is not an oracle);
 * * visit evidence rather than a message-attachment upload → 400;
 * * a photo already attached to a message → 409.
 */
async function assertAttachable(input: CreateMessageInput, photoIds: string[]): Promise<void> {
  if (photoIds.length > MAX_MESSAGE_ATTACHMENTS) {
    throw new ValidationError(`A message may carry at most ${MAX_MESSAGE_ATTACHMENTS} images`);
  }
  if (new Set(photoIds).size !== photoIds.length) {
    throw new ValidationError('attachmentPhotoIds must not repeat a photo');
  }
  if (photoIds.length === 0) {
    return;
  }

  const photos = await prisma.photo.findMany({
    where: { id: { in: photoIds }, clientId: input.clientId, uploadedById: input.senderId },
    select: {
      id: true,
      visitId: true,
      section: true,
      messageAttachment: { select: { id: true } },
    },
  });
  if (photos.length !== photoIds.length) {
    throw new NotFoundError('Attachment photo not found');
  }
  for (const photo of photos) {
    if (photo.visitId !== null || photo.section !== MESSAGE_ATTACHMENT_SECTION) {
      throw new ValidationError(
        'Only photos uploaded as message attachments can be attached; visit evidence cannot',
      );
    }
    if (photo.messageAttachment) {
      throw new ConflictError('Attachment photo is already attached to a message');
    }
  }
}

export async function createMessage(input: CreateMessageInput) {
  // A directed message must target a user inside the caller's tenant; a null
  // recipient is a broadcast to the whole client and needs no lookup.
  if (input.recipientId) {
    const recipient = await prisma.user.findFirst({
      where: { id: input.recipientId, clientId: input.clientId },
      select: { id: true },
    });
    if (!recipient) {
      throw new NotFoundError('Recipient not found');
    }
  }

  const photoIds = input.attachmentPhotoIds ?? [];
  await assertAttachable(input, photoIds);

  try {
    // The message and its attachment rows are one nested write, so a message
    // never lands with half its images.
    const row = await prisma.message.create({
      data: {
        clientId: input.clientId,
        senderId: input.senderId,
        recipientId: input.recipientId,
        body: input.body,
        attachments: {
          create: photoIds.map((photoId, position) => ({ photoId, position })),
        },
      },
      include: messageInclude,
    });
    return toMessageResponse(row);
  } catch (err) {
    // Two concurrent sends of the same upload both pass the check above; the
    // unique photo_id index lets exactly one of them win.
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      throw new ConflictError('Attachment photo is already attached to a message');
    }
    throw err;
  }
}

export interface ListMessagesInput {
  clientId: string;
  userId: string;
  limit: number;
  cursor?: string;
}

export async function listMessages(input: ListMessagesInput) {
  const rows = await prisma.message.findMany({
    where: {
      clientId: input.clientId,
      // Visible to the caller: sent by them, addressed to them, or a broadcast
      // (null recipient) within the client.
      OR: [
        { senderId: input.userId },
        { recipientId: input.userId },
        { recipientId: null },
      ],
    },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two messages share a createdAt — same reasoning as alerts.service.ts.
    //
    // COPYING THIS PATTERN: the tiebreaker's direction MUST match the primary
    // sort's direction (both `desc` here).
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    include: messageInclude,
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  const page = buildPage(rows, input.limit);
  return { ...page, data: page.data.map(toMessageResponse) };
}

export interface MarkMessageReadInput {
  messageId: string;
  clientId: string;
  userId: string;
}

export async function markMessageRead(input: MarkMessageReadInput) {
  // Only the recipient of a message in the caller's tenant may mark it read.
  const message = await prisma.message.findFirst({
    where: { id: input.messageId, clientId: input.clientId, recipientId: input.userId },
    select: { id: true },
  });
  if (!message) {
    throw new NotFoundError('Message not found');
  }

  const row = await prisma.message.update({
    where: { id: message.id },
    data: { readAt: new Date() },
    include: messageInclude,
  });
  return toMessageResponse(row);
}

export interface CreateAnnouncementInput {
  clientId: string;
  authorId: string;
  title: string;
  body: string;
}

export async function createAnnouncement(input: CreateAnnouncementInput) {
  return prisma.announcement.create({
    data: {
      clientId: input.clientId,
      authorId: input.authorId,
      title: input.title,
      body: input.body,
    },
  });
}

export interface ListAnnouncementsInput {
  clientId: string;
  limit: number;
  cursor?: string;
}

export async function listAnnouncements(input: ListAnnouncementsInput) {
  const rows = await prisma.announcement.findMany({
    where: { clientId: input.clientId },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two announcements share a createdAt — same reasoning as
    // alerts.service.ts.
    //
    // COPYING THIS PATTERN: the tiebreaker's direction MUST match the primary
    // sort's direction (both `desc` here).
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}
