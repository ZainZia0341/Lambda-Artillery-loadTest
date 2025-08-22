// logs-singlefile-ndjson.js
const fs = require('fs');
const path = require('path');

const REPORT_FILE = process.env.REPORT_FILE || path.join('.', 'lambda-test.ndjson');

function safeParseJSON(x) {
  if (typeof x !== 'string') return x;
  try { return JSON.parse(x); } catch { return x; }
}

module.exports = {
  markStart(req, ctx, ee, next) {
    ctx.vars._startTs = Date.now();
    return next();
  },

  logRequest(req, res, ctx, ee, next) {
    const started = ctx.vars._startTs || Date.now();
    const rt = res?.timings?.phases?.total ?? (Date.now() - started);

    const rec = {
      type: 'record',
      ts: new Date().toISOString(),
      // helpful for debugging multi-thread behavior:
      worker: process.env.LOCAL_WORKER_ID ?? null,
      pid: process.pid,
      responseTimeMs: rt,
      statusCode: res?.statusCode ?? null,
      request: {
        method: req?.method || 'POST',
        url: req?.url || '',
        headers: req?.headers || {},
        body: req?.json ?? req?.body ?? null,
      },
      response: {
        headers: res?.headers || {},
        body: safeParseJSON(res?.body),
      },
      aws: {
        requestId: res?.headers?.['x-amzn-requestid'] || res?.headers?.['x-request-id'] || 'N/A',
        traceId: res?.headers?.['x-amzn-trace-id'] || 'N/A',
      },
    };

    try {
      // one JSON object per line
      fs.appendFileSync(REPORT_FILE, JSON.stringify(rec) + '\n');
    } catch (e) {
      console.error('append failed:', e);
    }

    const indicator = rt > 3000 ? '🔴' : rt > 2000 ? '🟡' : '🟢';
    console.log(`[w:${process.env.LOCAL_WORKER_ID ?? '-'} pid:${process.pid}] ${indicator} ${rt}ms status=${res?.statusCode}`);

    return next();
  },
};
