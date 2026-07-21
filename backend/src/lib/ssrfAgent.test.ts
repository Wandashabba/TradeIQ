import { createServer } from "http";
import { fetch } from "undici";
import { createGuardedLookup, ssrfSafeAgent } from "./ssrfAgent";

/**
 * Stands in for `dns.lookup` so a rebinding answer can be served without
 * controlling real DNS — the attack needs an authoritative server with TTL=0,
 * which is not something a unit test can arrange.
 */
function fakeLookup(
  answer: string | Array<{ address: string; family: number }>,
) {
  return ((
    _hostname: string,
    _options: unknown,
    callback: (
      err: NodeJS.ErrnoException | null,
      address?: unknown,
      family?: number,
    ) => void,
  ) => {
    callback(null, answer, Array.isArray(answer) ? undefined : 4);
  }) as never;
}

function failingLookup(code: string) {
  return ((
    _hostname: string,
    _options: unknown,
    callback: (
      err: NodeJS.ErrnoException | null,
      address?: unknown,
      family?: number,
    ) => void,
  ) => {
    const err: NodeJS.ErrnoException = new Error("lookup failed");
    err.code = code;
    callback(err, "", undefined);
  }) as never;
}

function resolve(
  lookup: ReturnType<typeof createGuardedLookup>,
  host = "evil.example",
) {
  return new Promise<{ err: NodeJS.ErrnoException | null; address: unknown }>(
    (done) => {
      lookup(host, { all: true }, (err, address) => done({ err, address }));
    },
  );
}

describe("createGuardedLookup", () => {
  it("refuses an address that resolves private at connect time", async () => {
    // The rebinding case. assertPublicHostname already passed on an earlier,
    // public answer; this is the second resolution the attacker controls, and
    // it is the one the socket would actually use.
    const lookup = createGuardedLookup(
      fakeLookup([{ address: "169.254.169.254", family: 4 }]),
    );

    const { err } = await resolve(lookup);

    expect(err).not.toBeNull();
    expect(err?.code).toBe("ECONNREFUSED");
  });

  it("refuses when only ONE of several answers is private", async () => {
    // A round-robin record mixing a public and a private address must not be
    // let through on the strength of the public one — undici may connect to
    // either.
    const lookup = createGuardedLookup(
      fakeLookup([
        { address: "93.184.216.34", family: 4 },
        { address: "127.0.0.1", family: 4 },
      ]),
    );

    const { err } = await resolve(lookup);

    expect(err?.code).toBe("ECONNREFUSED");
  });

  it("refuses a private IPv6 answer", async () => {
    const lookup = createGuardedLookup(
      fakeLookup([{ address: "::1", family: 6 }]),
    );

    const { err } = await resolve(lookup);

    expect(err?.code).toBe("ECONNREFUSED");
  });

  it("allows a genuinely public answer through untouched", async () => {
    // The control. Without it a connector that refused everything would pass
    // every test above while breaking all webhook delivery.
    const answer = [{ address: "93.184.216.34", family: 4 }];
    const lookup = createGuardedLookup(fakeLookup(answer));

    const { err, address } = await resolve(lookup);

    expect(err).toBeNull();
    expect(address).toEqual(answer);
  });

  it("handles the single-address callback shape as well as the array one", async () => {
    // undici calls with { all: true }, but dns.lookup's contract allows either.
    // A connector that only understood arrays would treat a bare string as
    // having no addresses to check and wave it through.
    const lookup = createGuardedLookup(fakeLookup("10.0.0.5"));

    const { err } = await resolve(lookup);

    expect(err?.code).toBe("ECONNREFUSED");
  });

  it("passes a genuine resolution failure through unchanged", async () => {
    // A name that does not resolve is a different problem from one that
    // resolves somewhere forbidden, and the caller should see the real reason.
    const lookup = createGuardedLookup(failingLookup("ENOTFOUND"));

    const { err } = await resolve(lookup);

    expect(err?.code).toBe("ENOTFOUND");
  });

  it("does not tell the caller why it refused", async () => {
    // The error code is deliberately ECONNREFUSED — indistinguishable from a
    // subscriber simply being down. Anything more specific lets a webhook owner
    // use delivery failures to map our internal network.
    const lookup = createGuardedLookup(
      fakeLookup([{ address: "10.1.2.3", family: 4 }]),
    );

    const { err } = await resolve(lookup);

    expect(err?.code).toBe("ECONNREFUSED");
  });
});

describe("ssrfSafeAgent (integration)", () => {
  // Exercises the real exported Agent against a real socket. The unit tests
  // above prove the lookup function refuses correctly; they would all still
  // pass if that function were never wired into the Agent, or if the caller
  // used the global fetch (which ignores `dispatcher`). This is the test that
  // fails in that case.
  it("refuses a HOSTNAME that resolves to loopback, which plain fetch reaches", async () => {
    const server = createServer((_req, res) => {
      res.writeHead(200);
      res.end("SECRET-INTERNAL-DATA");
    });
    await new Promise<void>((resolve) =>
      server.listen(0, "127.0.0.1", resolve),
    );
    const { port } = server.address() as { port: number };
    // A hostname, deliberately. undici skips `connect.lookup` entirely when the
    // host is already a literal IP — there is nothing to resolve — so a test
    // using 127.0.0.1 would pass straight through the guard and prove nothing.
    // Rebinding requires a name anyway: that is the whole mechanism.
    const url = `http://localhost:${port}/`;

    try {
      // Control: the service really is reachable, so the refusal below is the
      // guard working rather than a dead server.
      const plain = await fetch(url);
      expect(plain.status).toBe(200);
      expect(await plain.text()).toBe("SECRET-INTERNAL-DATA");

      await expect(fetch(url, { dispatcher: ssrfSafeAgent })).rejects.toThrow();
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  });
});
