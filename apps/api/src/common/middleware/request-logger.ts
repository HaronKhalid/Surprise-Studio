import { randomUUID } from 'crypto';
import type { NextFunction, Request, Response } from 'express';

const VALID_ID = /^[A-Za-z0-9._-]{8,64}$/;

/**
 * One structured JSON line per request, for log aggregation. Records the *route pattern*
 * (/public/surprises/:slug), never the concrete URL: slugs are what protect unlisted surprises,
 * and tokens or personal content must not end up in logs. No bodies, headers or query strings.
 *
 * Accepts an incoming X-Request-Id (from a gateway) when it looks sane, so one id can be followed
 * across services; otherwise generates one. It is returned in the response for support requests.
 */
export function requestLogger(write: (line: string) => void = (l) => process.stdout.write(l + '\n')) {
  return (req: Request, res: Response, next: NextFunction) => {
    const incoming = req.headers['x-request-id'];
    const requestId = typeof incoming === 'string' && VALID_ID.test(incoming) ? incoming : randomUUID();
    res.setHeader('X-Request-Id', requestId);
    const start = process.hrtime.bigint();

    res.on('finish', () => {
      write(
        JSON.stringify({
          ts: new Date().toISOString(),
          level: res.statusCode >= 500 ? 'error' : 'info',
          msg: 'request',
          requestId,
          method: req.method,
          route: (req.route?.path as string | undefined) ?? '(unmatched)',
          status: res.statusCode,
          ms: Math.round(Number(process.hrtime.bigint() - start) / 1e5) / 10,
          userId: (req as Request & { user?: { id: string } }).user?.id,
        }),
      );
    });
    next();
  };
}
