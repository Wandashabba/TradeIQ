import { ALLOW_ALL, DISALLOW_ALL, parseRobots, robotsForStatus } from './robots';

const TOKEN = 'TradeIQPriceBot';

describe('robots.txt parser (RFC 9309)', () => {
  it('allows everything when there are no rules', () => {
    expect(parseRobots('', TOKEN).isAllowed('/p/anything')).toBe(true);
  });

  it('applies the * group when no group names our token', () => {
    const policy = parseRobots('User-agent: *\nDisallow: /checkout\n', TOKEN);
    expect(policy.isAllowed('/checkout/basket')).toBe(false);
    expect(policy.isAllowed('/p/cola-2l')).toBe(true);
  });

  it('uses our own group instead of *, matching the token case-insensitively', () => {
    const policy = parseRobots(
      'User-agent: *\nDisallow: /\n\nUser-agent: tradeiqpricebot\nAllow: /p/\nDisallow: /\n',
      TOKEN,
    );
    expect(policy.isAllowed('/p/cola-2l')).toBe(true);
    expect(policy.isAllowed('/search?q=cola')).toBe(false);
  });

  it('does not treat a different bot whose name merely contains ours as us', () => {
    const policy = parseRobots('User-agent: TradeIQPriceBotEvil\nDisallow: /\n', TOKEN);
    expect(policy.isAllowed('/p/x')).toBe(true);
  });

  it('combines every group that names our token', () => {
    const policy = parseRobots(
      'User-agent: TradeIQPriceBot\nDisallow: /a\n\nUser-agent: Other\nDisallow: /b\n\nUser-agent: TradeIQPriceBot\nDisallow: /c\n',
      TOKEN,
    );
    expect(policy.isAllowed('/a')).toBe(false);
    expect(policy.isAllowed('/b')).toBe(true);
    expect(policy.isAllowed('/c')).toBe(false);
  });

  it('shares rules across consecutive user-agent lines', () => {
    const policy = parseRobots('User-agent: Googlebot\nUser-agent: TradeIQPriceBot\nDisallow: /private\n', TOKEN);
    expect(policy.isAllowed('/private/x')).toBe(false);
  });

  it('picks the longest matching rule, and allow on a tie', () => {
    const policy = parseRobots(
      'User-agent: *\nDisallow: /shop\nAllow: /shop/p/\nDisallow: /shop/p/secret\nAllow: /tie\nDisallow: /tie\n',
      TOKEN,
    );
    expect(policy.isAllowed('/shop/cart')).toBe(false);
    expect(policy.isAllowed('/shop/p/cola')).toBe(true);
    expect(policy.isAllowed('/shop/p/secret-sale')).toBe(false);
    expect(policy.isAllowed('/tie')).toBe(true);
  });

  it('supports * wildcards and the $ end anchor', () => {
    const policy = parseRobots('User-agent: *\nDisallow: /*?sort=\nDisallow: /*.json$\n', TOKEN);
    expect(policy.isAllowed('/p/cola?sort=price')).toBe(false);
    expect(policy.isAllowed('/p/cola')).toBe(true);
    expect(policy.isAllowed('/api/prices.json')).toBe(false);
    expect(policy.isAllowed('/api/prices.json?x=1')).toBe(true);
  });

  it('matches the query string as part of the path', () => {
    const policy = parseRobots('User-agent: *\nDisallow: /search?\n', TOKEN);
    expect(policy.isAllowed('/search?q=cola')).toBe(false);
  });

  it('ignores comments, blank lines, sitemaps, unknown keys and rules before any user-agent', () => {
    const policy = parseRobots(
      '# hello\nDisallow: /orphan\nSitemap: https://shop.example.test/sitemap.xml\n\nUser-agent: * # everyone\nFoo: bar\nDisallow: /x # no x\n',
      TOKEN,
    );
    expect(policy.isAllowed('/orphan')).toBe(true);
    expect(policy.isAllowed('/x')).toBe(false);
  });

  it('treats an empty Disallow as allowing everything', () => {
    expect(parseRobots('User-agent: *\nDisallow:\n', TOKEN).isAllowed('/p/x')).toBe(true);
  });

  it('normalises percent-encoding before matching', () => {
    const policy = parseRobots('User-agent: *\nDisallow: /café\n', TOKEN);
    expect(policy.isAllowed('/caf%C3%A9')).toBe(false);
    expect(policy.isAllowed('/caf%c3%a9/menu')).toBe(false);
  });

  it('always allows /robots.txt itself', () => {
    expect(parseRobots('User-agent: *\nDisallow: /\n', TOKEN).isAllowed('/robots.txt')).toBe(true);
  });

  it('reads a crawl-delay from the matched group', () => {
    expect(parseRobots('User-agent: *\nCrawl-delay: 30\nDisallow: /x\n', TOKEN).crawlDelaySeconds).toBe(30);
    expect(parseRobots('User-agent: *\nDisallow: /x\n', TOKEN).crawlDelaySeconds).toBeNull();
  });

  it('handles CRLF line endings', () => {
    expect(parseRobots('User-agent: *\r\nDisallow: /p\r\n', TOKEN).isAllowed('/p/x')).toBe(false);
  });
});

describe('robots.txt status handling', () => {
  it('parses a 2xx body', () => {
    expect(robotsForStatus(200)).toBeNull();
  });

  it('treats a missing robots.txt (404/410) as no restrictions', () => {
    expect(robotsForStatus(404)).toBe(ALLOW_ALL);
    expect(robotsForStatus(410)).toBe(ALLOW_ALL);
  });

  it('treats a refused robots.txt (401/403/429) as complete disallow', () => {
    for (const status of [401, 403, 429]) expect(robotsForStatus(status)).toBe(DISALLOW_ALL);
  });

  it('treats a server error or redirect as complete disallow', () => {
    for (const status of [301, 500, 503]) expect(robotsForStatus(status)).toBe(DISALLOW_ALL);
  });
});
