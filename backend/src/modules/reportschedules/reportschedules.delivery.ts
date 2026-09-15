import { enqueueWebhookEvent } from '../webhooks/webhooks.service';

/**
 * Where a generated report goes (#66): one channel per transport, each
 * reporting what it actually did.
 *
 * Built: **webhook**. The run is announced as a `report.generated` event to the
 * client's active webhooks subscribed to it, through the ordinary webhook
 * fan-out — so it gets the signed body, the retry schedule, the delivery log
 * and the health state every other event gets.
 *
 * Not built: **email**. It needs a mail provider and credentials. The stub
 * below is the seam: a real implementation replaces it in
 * `REPORT_DELIVERY_CHANNELS` and nothing else changes. Until then it records,
 * honestly, that email was not sent, and the recipients stay stored on the
 * schedule for when it is.
 */

/** The webhook event a report run is announced as. */
export const REPORT_GENERATED_EVENT = 'report.generated';

export type ReportDeliveryStatus =
  /** Handed to the transport; for webhooks, delivery rows exist and retry. */
  | 'queued'
  /** The channel works but nobody is listening (no subscribed webhooks). */
  | 'no_subscribers'
  /** The channel is not set up on this deployment (email). */
  | 'not_configured'
  /** The channel tried and failed before anything was queued. */
  | 'failed';

/** What one channel did with one run. Stored on the run, returned by the API. */
export interface ReportDeliveryOutcome {
  channel: string;
  status: ReportDeliveryStatus;
  /** Where it was queued to: webhook URLs; for email, the stored recipients. */
  targets: string[];
  /** The webhook delivery rows created, to follow in the delivery log. */
  webhookDeliveryIds?: string[];
  /** A human-readable reason for any status other than `queued`. */
  detail?: string;
}

/**
 * The `report.generated` webhook payload. Deliberately a pointer, not the rows:
 * a report has no row cap (an unfiltered visits report is a tenant's whole
 * visit history), and the body is stored on every delivery row and re-sent on
 * every retry. The subscriber fetches the CSV from `csvPath` with a
 * manager/admin bearer token. The payload itself stays a few hundred bytes.
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

export const EMAIL_NOT_CONFIGURED = 'Email delivery not configured';

/** The email seam. Sends nothing; says so. */
export const emailDeliveryChannelStub: ReportDeliveryChannel = {
  name: 'email',
  async deliver({ recipients }) {
    return {
      channel: 'email',
      status: 'not_configured',
      targets: recipients,
      detail: EMAIL_NOT_CONFIGURED,
    };
  },
};

export const REPORT_DELIVERY_CHANNELS: readonly ReportDeliveryChannel[] = [
  webhookDeliveryChannel,
  emailDeliveryChannelStub,
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
