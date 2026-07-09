import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

export interface CreateMessageInput {
  clientId: string;
  senderId: string;
  body: string;
  recipientId?: string;
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

  return prisma.message.create({
    data: {
      clientId: input.clientId,
      senderId: input.senderId,
      recipientId: input.recipientId,
      body: input.body,
    },
  });
}

export interface ListMessagesInput {
  clientId: string;
  userId: string;
}

export async function listMessages(input: ListMessagesInput) {
  return prisma.message.findMany({
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
    orderBy: { createdAt: 'desc' },
  });
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

  return prisma.message.update({
    where: { id: message.id },
    data: { readAt: new Date() },
  });
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

export async function listAnnouncements(clientId: string) {
  return prisma.announcement.findMany({
    where: { clientId },
    orderBy: { createdAt: 'desc' },
  });
}
