import { enqueueWebhookEvent } from '../webhooks/webhooks.service';
import { emailDeliveryChannel } from './reportschedules.email';

export { EMAIL_NOT_CONFIGURED } from './reportschedules.email';

/**
 * Where a generated report goes (#66): one channel per transport, each
 * reporting what it actually did.
 *
 * - **webhook**. The run is announced as a `report.generated` event to the
 *   client's active webhooks subscribed to it, through the ordinary webhook
 *   fan-out — so it gets the signed body, the retry schedule, the delivery log
 *   and the health state every other event gets.
 * - **email** (reportschedules.email.ts). One message per schedule recipient
 *   over SMTP, retried on the same schedule. Off until SMTP_* is configured,
 *   and the run records `not_configured` with the reason until then.
 */

/** The webhook event a report run is announced as. */
export const REPORT_GENERATED_EVENT = 'report.generated';

export type ReportDeliveryStatus =
  /** Handed to the transport; delivery rows exist and retry. */
  | 'queued'
  /** The channel works but nobody is listening (no subscribed webhooks, no email recipients). */
  | 'no_subscribers'
  /** The channel is not set up on this deployment (email without SMTP). */
  | 'not_configured'
  /** The channel tried and failed before anything was queued. */
  | 'failed';

/** What one channel did with one run. Stored on the run, returned by the API. */
export interface ReportDeliveryOutcome {
  channel: string;
  status: ReportDeliveryStatus;
  /** Where it was queued to: webhook URLs; for email, the recipients. */
  targets: string[];
  /** The webhook delivery rows created, to follow in the delivery log. */
  webhookDeliveryIds?: string[];
  /** The email delivery rows created, one per recipient. */
  emailDeliveryIds?: string[];
  /** A human-readable reason for any status other than `queued`. */
  detail?: string;
}

/**
 * The `report.generated` webhook payload. Deliberately a pointer, not the rows:
 * a report has no row cap (an unfiltered visits report is a tenant's whole
 * visit history), and the body is stored on every delivery row and re-sent on
 * every retry. The subscriber fetches the CSV from `csvDownloadUrl` (no token
 * needed) or from `csvPath` with a manager/admin bearer token. The payload
 * itself stays a few hundred bytes.
 */
export interface ReportGeneratedPayload {
  scheduleId: string;
  reportId: string;
  reportName: string;
  reportType: string;
  runId: string;
  trigger: 'scheduled' | 'manual';
  generatedAt: string;
  rowCount: number;
  /** Path of the run's CSV on this API. */
  csvPath: string;
  /** `csvPath` on `PUBLIC_API_URL`, when that is configured; otherwise null. */
  csvUrl: string | null;
  /**
   * A signed link to the run's CSV that needs no bearer token, when
   * PUBLIC_API_URL and REPORT_LINK_SECRET are configured; otherwise null.
   */
  csvDownloadUrl: string | null;
  /** When `csvDownloadUrl` stops working; null with it. */
  csvDownloadExpiresAt: string | null;
}

export interface ReportDeliveryContext {
  clientId: string;
  recipients: string[];
  payload: ReportGeneratedPayload;
}

export interface ReportDeliveryChannel {
  readonly name: string;
  deliver(context: ReportDeliveryContext): Promise<ReportDeliveryOutcome>;
}

export const webhookDeliveryChannel: ReportDeliveryChannel = {
  name: 'webhook',
  async deliver({ clientId, payload }) {
    const queued = await enqueueWebhookEvent(clientId, REPORT_GENERATED_EVENT, payload);
    if (queued.length === 0) {
      return {
        channel: 'webhook',
        status: 'no_subscribers',
        targets: [],
        webhookDeliveryIds: [],
        detail: `No active webhook is subscribed to ${REPORT_GENERATED_EVENT}`,
      };
    }
    return {
      channel: 'webhook',
      status: 'queued',
      targets: queued.map((q) => q.url),
      webhookDeliveryIds: queued.map((q) => q.deliveryId),
    };
  },
};

export { emailDeliveryChannel };

export const REPORT_DELIVERY_CHANNELS: readonly ReportDeliveryChannel[] = [
  webhookDeliveryChannel,
  emailDeliveryChannel,
];

/**
 * Runs every channel and collects their outcomes. Never throws: the report has
 * already been generated and the run recorded, so a channel that blows up is
 * reported as `failed` on that channel rather than failing the run.
 */
export async function deliverReport(
  context: ReportDeliveryContext,
  channels: readonly ReportDeliveryChannel[] = REPORT_DELIVERY_CHANNELS,
): Promise<ReportDeliveryOutcome[]> {
  const outcomes: ReportDeliveryOutcome[] = [];
  for (const channel of channels) {
    try {
      outcomes.push(await channel.deliver(context));
    } catch (err) {
      console.error(`Report delivery via ${channel.name} failed:`, err);
      outcomes.push({
        channel: channel.name,
        status: 'failed',
        targets: [],
        detail: err instanceof Error ? err.message.slice(0, 500) : String(err).slice(0, 500),
      });
    }
  }
  return outcomes;
}

/** What `deliveredTo` reports: the targets something was actually queued to. */
export function deliveredTargets(outcomes: readonly ReportDeliveryOutcome[]): string[] {
  return outcomes.filter((o) => o.status === 'queued').flatMap((o) => o.targets);
}
