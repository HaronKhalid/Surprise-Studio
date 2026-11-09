import { EventEmitter } from 'events';
import { requestLogger } from './request-logger';

function run(req: Record<string, unknown>, status = 200, headers: Record<string, string> = {}) {
  const lines: string[] = [];
  const res: any = Object.assign(new EventEmitter(), { statusCode: status, headers: {} as Record<string, string>, setHeader(k: string, v: string) { this.headers[k] = v; } });
  const next = jest.fn();
  requestLogger((l) => lines.push(l))({ method: 'GET', headers, ...req } as any, res, next);
  res.emit('finish');
  return { line: JSON.parse(lines[0]), res, next };
}

describe('requestLogger', () => {
  it('logs one structured line per request and continues the chain', () => {
    const { line, next } = run({ route: { path: '/api/v1/templates' } });
    expect(next).toHaveBeenCalledTimes(1);
    expect(line).toMatchObject({ level: 'info', msg: 'request', method: 'GET', route: '/api/v1/templates', status: 200 });
    expect(typeof line.ms).toBe('number');
    expect(line.ts).toMatch(/^\d{4}-\d\d-\d\dT/);
  });

  it('logs the route pattern, never the concrete URL, so unlisted-surprise slugs stay out of logs', () => {
    const { line } = run({ route: { path: '/api/v1/public/surprises/:slug' }, originalUrl: '/api/v1/public/surprises/SECRETslug1?token=abc' });
    expect(line.route).toBe('/api/v1/public/surprises/:slug');
    expect(JSON.stringify(line)).not.toContain('SECRETslug1');
    expect(JSON.stringify(line)).not.toContain('token');
  });

  it('never logs authorization, cookies or bodies', () => {
    const { line } = run({ route: { path: '/x' }, body: { password: 'hunter2' } }, 200, { authorization: 'Bearer secret.jwt.token', cookie: 'a=b' });
    const text = JSON.stringify(line);
    for (const secret of ['hunter2', 'secret.jwt.token', 'a=b']) expect(text).not.toContain(secret);
  });

  it('marks 5xx as errors and unmatched routes explicitly', () => {
    expect(run({}, 500).line).toMatchObject({ level: 'error', route: '(unmatched)' });
  });

  it('includes the user id when the request was authenticated', () => {
    expect(run({ route: { path: '/x' }, user: { id: 'u-1' } }).line.userId).toBe('u-1');
  });

  it('generates a request id, returns it, and reuses a sane incoming one', () => {
    const generated = run({ route: { path: '/x' } });
    expect(generated.res.headers['X-Request-Id']).toBe(generated.line.requestId);
    expect(generated.line.requestId).toMatch(/^[0-9a-f-]{36}$/);

    const reused = run({ route: { path: '/x' } }, 200, { 'x-request-id': 'gateway-abc-12345' });
    expect(reused.line.requestId).toBe('gateway-abc-12345');
  });

  it.each(['short', 'has spaces in it!!', 'x'.repeat(200), '<script>alert(1)</script>'])('ignores a malformed incoming request id %p', (bad) => {
    const { line } = run({ route: { path: '/x' } }, 200, { 'x-request-id': bad });
    expect(line.requestId).not.toBe(bad);
  });
});
