import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePublicHttpUrl } from '../../lib/urlGuard';
import {
  createWebhook,
  deleteWebhook,
  findWebhookForClient,
  listWebhooksForClient,
  updateWebhook,
} from './webhooks.service';

export const webhooksRouter = Router();
webhooksRouter.use(requireAuth);

webhooksRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { url, event, secret } = req.body as {
    url?: unknown;
    event?: unknown;
    secret?: unknown;
  };

  if (
    typeof url !== 'string' ||
    parsePublicHttpUrl(url) === null ||
    typeof event !== 'string' ||
    event.length === 0 ||
    (secret !== undefined && typeof secret !== 'string')
  ) {
    res.status(400).json({
      error:
        'url must be a public http(s) URL (private and link-local addresses are rejected) and event is required; secret must be a string when given',
    });
    return;
  }

  const webhook = await createWebhook({
    clientId: req.user!.clientId,
    url,
    event,
    secret,
  });
  res.status(201).json(webhook);
});

webhooksRouter.get('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const webhooks = await listWebhooksForClient(req.user!.clientId);
  res.status(200).json(webhooks);
});

webhooksRouter.patch('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { active, url, event } = req.body as {
    active?: unknown;
    url?: unknown;
    event?: unknown;
  };

  if (
    (active !== undefined && typeof active !== 'boolean') ||
    (url !== undefined && (typeof url !== 'string' || parsePublicHttpUrl(url) === null)) ||
    (event !== undefined && (typeof event !== 'string' || event.length === 0))
  ) {
    res.status(400).json({
      error:
        'active must be a boolean, url (when given) must be a public http(s) URL, and event must be a non-empty string',
    });
    return;
  }
  if (active === undefined && url === undefined && event === undefined) {
    res.status(400).json({ error: 'At least one of active, url, or event is required' });
    return;
  }

  const { id } = req.params as { id: string };
  // Tenant check: throws NotFoundError (404) when the row is another client's.
  const webhook = await findWebhookForClient(id, req.user!.clientId);

  const updated = await updateWebhook(webhook.id, {
    active: active as boolean | undefined,
    url: url as string | undefined,
    event: event as string | undefined,
  });
  res.status(200).json(updated);
});

webhooksRouter.delete('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  // Tenant check: throws NotFoundError (404) when the row is another client's.
  const webhook = await findWebhookForClient(id, req.user!.clientId);
  await deleteWebhook(webhook.id);
  res.status(204).send();
});
