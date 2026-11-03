// dsh-mmy-ttslive · 字幕接口层
// 本地 HTTP，默认 7788：POST /caption 入队，窗口 GET /next 拉最新一段。
// 额外保留最近 60 条历史，供窗口做「上一句 / 下一句 / 历史记录」。
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const CACHE = path.join(__dirname, '.cache');
fs.mkdirSync(CACHE, { recursive: true });

const PORTS = [7788, 7789, 7790, 7791];
const HISTORY_MAX = 60;

let latest = { seq: 0, text: '', index: 0, total: 0, prev: '', next: '', live: false, ts: 0 };
let history = []; // 最近的已播句子，旧→新
let skin = 'a';

function send(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve) => {
    let raw = '';
    req.setEncoding('utf8');
    req.on('data', (c) => {
      raw += c;
      if (raw.length > 200000) req.destroy();
    });
    req.on('end', () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        resolve({});
      }
    });
    req.on('error', () => resolve({}));
  });
}

function pushHistory(entry) {
  history.push(entry);
  if (history.length > HISTORY_MAX) history = history.slice(-HISTORY_MAX);
}

async function route(req, res) {
  const url = new URL(req.url, 'http://127.0.0.1');
  const p = url.pathname;

  if (p === '/health') return send(res, 200, { ok: true, seq: latest.seq, skin });

  if (p === '/next') {
    const since = Number(url.searchParams.get('since') || 0);
    if (latest.seq > since) return send(res, 200, { has: true, ...latest });
    return send(res, 200, { has: false, seq: latest.seq });
  }

  if (p === '/history') {
    const limit = Math.max(1, Math.min(HISTORY_MAX, Number(url.searchParams.get('limit') || 20)));
    return send(res, 200, { items: history.slice(-limit), total: history.length });
  }

  if (p === '/caption' && req.method === 'POST') {
    const body = await readBody(req);
    const text = String(body.text || '').trim();
    if (!text) return send(res, 400, { ok: false, error: 'empty text' });
    latest = {
      seq: (console.log(`[caption] t=${Date.now()} idx=${Number(body.index || 0)}/${Number(body.total || 0)} dur=${Number(body.duration || 0)} text=${String(body.text || '').slice(0, 16)}`), latest.seq + 1),
      text,
      index: Number(body.index || 0),
      total: Number(body.total || 0),
      prev: String(body.prev || ''),
      next: String(body.next || ''),
      duration: Math.max(0, Number(body.duration || 0)),
      breaks: Array.isArray(body.breaks) ? body.breaks.map((x) => Math.max(0, Math.min(1, Number(x) || 0))) : [],
      speed: Math.max(0.1, Number(body.speed || 1.12)),
      live: true,
      ts: Date.now(),
    };
    pushHistory({ seq: latest.seq, text, index: latest.index, total: latest.total, ts: latest.ts });
    return send(res, 200, { ok: true, seq: latest.seq });
  }

  // 播放结束：只把 live 置 false，不清文本——字幕窗要留在屏幕上，不消失。
  if (p === '/clear' && req.method === 'POST') {
    latest = { ...latest, seq: latest.seq + 1, live: false, ts: Date.now() };
    return send(res, 200, { ok: true, seq: latest.seq });
  }

  if (p === '/skin') {
    if (req.method === 'POST') {
      const body = await readBody(req);
      const next = String(body.skin || '').toLowerCase();
      if (next === 'a' || next === 'b') skin = next;
      return send(res, 200, { ok: true, skin });
    }
    return send(res, 200, { skin });
  }

  if (p === '/state') {
    return send(res, 200, {
      skin,
      seq: latest.seq,
      text: latest.text,
      index: latest.index,
      total: latest.total,
      live: latest.live,
      historyTotal: history.length,
    });
  }

  return send(res, 404, { ok: false, error: 'not found' });
}

function listen(i) {
  if (i >= PORTS.length) {
    console.error('[ttslive] 7788-7791 全被占用，放弃');
    process.exit(1);
  }
  const port = PORTS[i];
  const server = http.createServer((req, res) => {
    route(req, res).catch((err) => {
      try {
        send(res, 500, { ok: false, error: String(err && err.message) });
      } catch {}
    });
  });
  server.on('error', (err) => {
    if (err && err.code === 'EADDRINUSE') return listen(i + 1);
    console.error('[ttslive] 监听失败：', err && err.message);
    process.exit(1);
  });
  server.listen(port, '127.0.0.1', () => {
    fs.writeFileSync(path.join(CACHE, 'ttslive-port.txt'), String(port), 'utf8');
    console.log('[ttslive] 字幕接口在 http://127.0.0.1:' + port);
  });
}

listen(0);
