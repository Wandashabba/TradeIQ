import { createServer, Server } from 'http';
import { app } from './app';

/**
 * One listening HTTP server per test file, shared by every request in it.
 *
 * Import this instead of `app` in route tests:
 *
 * ```ts
 * import { httpServer as app } from '../../testHttpServer';
 * ```
 *
 * ## Why this exists (#227)
 *
 * `request(app)` hands supertest an express *function*. Supertest wraps it in a
 * fresh `http.Server` and, seeing no address, calls `listen(0)` — see
 * `supertest/lib/test.js`:
 *
 * ```js
 * if (!addr) this._server = app.listen(0);
 * ```
 *
 * and closes that server again in `end()`. Because `request(app)` is written
 * out at every call site, that is a socket bound and torn down **per HTTP
 * request** — thousands per suite run, across four workers.
 *
 * Ephemeral ports linger in `TIME_WAIT` after close. At that churn a port can
 * be rebound while a previous connection is still draining, and a response
 * crosses into the wrong client. That is what #227 caught: an `errorHandler`
 * test with a single throwing route — no path through it can produce a 400 —
 * received a 400, which means the response came from a different app entirely.
 * A *wrong* response reaching a test is worse than a missing row, because it
 * can make a test pass for the wrong reason rather than merely fail.
 *
 * Handing supertest a server that is **already listening** takes the other
 * branch: `addr` is set, so it neither listens nor closes, and every request in
 * the file reuses this one socket. Bindings per run drop from thousands to one
 * per test file.
 *
 * `unref()` keeps the open handle from holding the worker's event loop open, so
 * no `afterAll` teardown is needed and a forgotten one cannot hang a run.
 */
export const httpServer: Server = createServer(app).listen(0);
httpServer.unref();
