import { PushMessage, PushSendResult, PushSender } from '../modules/push/push.sender';

/**
 * A push sender that records instead of sending (#67). Tokens added to
 * `invalid` come back as FCM would report an unregistered device; `failWith`
 * makes every send reject, as a network failure would.
 */
export class RecordingPushSender implements PushSender {
  readonly enabled = true;
  readonly batches: PushMessage[][] = [];
  readonly invalid = new Set<string>();
  failWith: Error | null = null;

  async send(messages: PushMessage[]): Promise<PushSendResult> {
    if (this.failWith) throw this.failWith;
    this.batches.push(messages);
    const invalidTokens = messages.filter((m) => this.invalid.has(m.token)).map((m) => m.token);
    return { sent: messages.length - invalidTokens.length, invalidTokens };
  }

  /** Every message sent so far, flattened. */
  get messages(): PushMessage[] {
    return this.batches.flat();
  }

  /** Messages addressed to any of `tokens`, sorted by token for stable asserts. */
  to(...tokens: string[]): PushMessage[] {
    return this.messages
      .filter((m) => tokens.includes(m.token))
      .sort((a, b) => a.token.localeCompare(b.token));
  }

  reset(): void {
    this.batches.length = 0;
    this.invalid.clear();
    this.failWith = null;
  }
}
