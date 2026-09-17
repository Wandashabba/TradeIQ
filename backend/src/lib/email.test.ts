import { normalizeEmail } from './email';

describe('normalizeEmail', () => {
  it('folds the whole address to lower case', () => {
    expect(normalizeEmail('Agent@Demo-FMCG.TradeIQ.com')).toBe('agent@demo-fmcg.tradeiq.com');
  });

  it('strips surrounding whitespace', () => {
    expect(normalizeEmail('  agent@demo-fmcg.tradeiq.com  ')).toBe('agent@demo-fmcg.tradeiq.com');
  });

  // The reported bug exactly: an Android keyboard capitalises the first letter,
  // and a paste can bring a space along.
  it('handles capitalisation and whitespace together (#351)', () => {
    expect(normalizeEmail(' Agent@demo-fmcg.tradeiq.com ')).toBe('agent@demo-fmcg.tradeiq.com');
    expect(normalizeEmail('AGENT@DEMO-FMCG.TRADEIQ.COM')).toBe('agent@demo-fmcg.tradeiq.com');
  });

  it('leaves an already-canonical address untouched', () => {
    expect(normalizeEmail('agent@demo-fmcg.tradeiq.com')).toBe('agent@demo-fmcg.tradeiq.com');
  });

  // Normalising a stored value must be a no-op, or re-running provisioning
  // against existing rows would rewrite them.
  it('is idempotent', () => {
    const once = normalizeEmail('  Agent@Demo-FMCG.TradeIQ.com ');
    expect(normalizeEmail(once)).toBe(once);
  });

  it('only touches the ends, never whitespace inside the address', () => {
    expect(normalizeEmail('  A B@demo.com  ')).toBe('a b@demo.com');
  });
});
