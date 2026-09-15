import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import {
  MAX_MESSAGE_ATTACHMENTS,
  createAnnouncement,
  createMessage,
  listAnnouncements,
  listMessages,
  markMessageRead,
} from './collaboration.service';

export const messagesRouter = Router();
messagesRouter.use(requireAuth);

export const announcementsRouter = Router();
announcementsRouter.use(requireAuth);

messagesRouter.post('/', async (req: AuthedRequest, res) => {
  const { body, recipientId, attachmentPhotoIds } = req.body as {
    body?: unknown;
    recipientId?: unknown;
    attachmentPhotoIds?: unknown;
  };

  if (
    attachmentPhotoIds !== undefined &&
    (!Array.isArray(attachmentPhotoIds) ||
      !attachmentPhotoIds.every((id): id is string => typeof id === 'string' && id.length > 0))
  ) {
    res.status(400).json({ error: 'attachmentPhotoIds must be an array of photo id strings' });
    return;
  }
  const photoIds = (attachmentPhotoIds as string[] | undefined) ?? [];
  if (photoIds.length > MAX_MESSAGE_ATTACHMENTS) {
    res
      .status(400)
      .json({ error: `A message may carry at most ${MAX_MESSAGE_ATTACHMENTS} images` });
    return;
  }

  // An image can be the whole message, so the body may be blank when at least
  // one attachment is present — but it must still be a string.
  if (
    typeof body !== 'string' ||
    (body.trim().length === 0 && photoIds.length === 0) ||
    (recipientId !== undefined && typeof recipientId !== 'string')
  ) {
    res.status(400).json({
      error:
        'body is required and must be a non-empty string (it may be blank when ' +
        'attachmentPhotoIds is non-empty); recipientId must be a string when given',
    });
    return;
  }

  const message = await createMessage({
    clientId: req.user!.clientId,
    senderId: req.user!.userId,
    body,
    recipientId: recipientId as string | undefined,
    attachmentPhotoIds: photoIds,
  });
  res.status(201).json(message);
});

messagesRouter.get('/', async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  const page = await listMessages({
    clientId: req.user!.clientId,
    userId: req.user!.userId,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

messagesRouter.patch('/:id/read', async (req: AuthedRequest, res) => {
  const { id: messageId } = req.params as { id: string };
  const message = await markMessageRead({
    messageId,
    clientId: req.user!.clientId,
    userId: req.user!.userId,
  });
  res.status(200).json(message);
});

announcementsRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { title, body } = req.body as {
    title?: unknown;
    body?: unknown;
  };

  if (
    typeof title !== 'string' ||
    title.trim().length === 0 ||
    typeof body !== 'string' ||
    body.trim().length === 0
  ) {
    res.status(400).json({ error: 'title and body are required' });
    return;
  }

  const announcement = await createAnnouncement({
    clientId: req.user!.clientId,
    authorId: req.user!.userId,
    title,
    body,
  });
  res.status(201).json(announcement);
});

announcementsRouter.get('/', async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  const page = await listAnnouncements({ clientId: req.user!.clientId, limit, cursor });
  res.status(200).json(page);
});
