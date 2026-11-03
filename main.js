'use strict';
/**
 * dsh-mmy-ttslive · 台词悬浮窗（主进程）
 *
 * 干什么：一个透明置顶的小窗，把本地 TTS 正在播的「这一段」显示成字幕。
 *   外面（say.py / say.js / 任何脚本）只要 POST 一段文本过来，窗就淡入显示；
 *   念完这段、隔几秒没新内容，自己淡出。
 *
 * 对外接口（只监听 127.0.0.1，端口见 userData/port.txt，默认 7788）：
 *   POST /caption  {text, index?, total?, hold?}  显示一段字幕（index/total 给「第 N/M 段」）
 *   POST /clear                                   立刻淡出
 *   POST /skin     {name:"A"|"B"}                 切皮肤（A 通栏条幅 / B 悬浮卡）
 *   POST /show | /hide                            强制显隐
 *   GET  /health                                  状态
 *   GET  /screenshot                              截当前窗，返回 PNG 路径（自检用）
 *   GET  /events                                  SSE，订阅同样的 caption/skin/clear 事件
 *
 * 两套皮肤尺寸：A 960×118（底部居中，默认）、B 720×190。
 * 位置记忆：拖动后写 userData/state.json，下次按上次位置开；换皮肤保持底边与水平中心。
 */
const { app, BrowserWindow, ipcMain, screen } = require('electron');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

process.on('uncaughtException', (err) => console.error('[ttslive] 未捕获异常：', err));
process.on('unhandledRejection', (err) => console.error('[ttslive] 未处理的 Promise 拒绝：', err));

const SKINS = {
  A: { w: 960, h: 118, label: '通栏条幅' },
  B: { w: 720, h: 190, label: '悬浮卡' },
};const DEFAULT_SKIN = 'A';
const DEFAULT_GAP_BOTTOM = 80;
const PORT_CANDIDATES = [7788, 7789, 7790, 7791];

let win = null;
let userDir = '';
let stateFile = '';
let portFile = '';
let httpPort = 0;
let state = {};
let sseClients = new Set();
let saveTimer = null;

// ---------- 状态 ----------
function loadState() {
  try {
    return JSON.parse(fs.readFileSync(stateFile, 'utf8'));
  } catch {
    return {};
  }
}

function saveState(patch) {
  state = { ...state, ...patch };
  try {
    fs.mkdirSync(userDir, { recursive: true });
    fs.writeFileSync(stateFile, JSON.stringify(state, null, 2), 'utf8');
  } catch (err) {
    console.warn('[ttslive] 状态没存下来：', err.message);
  }
  return state;
}

function currentSkin() {
  return SKINS[state.skin] ? state.skin : DEFAULT_SKIN;
}

// ---------- 窗口 ----------
function resolvePosition(skinName) {
  const { w, h } = SKINS[skinName];
  const displays = screen.getAllDisplays();
  // 上次位置还落在某块屏幕里就用它，否则回到底部居中
  if (Number.isFinite(state.x) && Number.isFinite(state.y)) {
    const hit = displays.some((d) => {
      const a = d.workArea;
      return (
        state.x >= a.x - w + 60 &&
        state.y >= a.y - 20 &&
        state.x <= a.x + a.width - 60 &&
        state.y <= a.y + a.height - 40
      );
    });
    if (hit) return { x: Math.round(state.x), y: Math.round(state.y) };
  }
  const { workArea } = screen.getPrimaryDisplay();
  return {
    x: Math.round(workArea.x + (workArea.width - w) / 2),
    y: Math.round(workArea.y + workArea.height - h - DEFAULT_GAP_BOTTOM),
  };
}

function createWindow() {
  const skin = currentSkin();
  const { w, h } = SKINS[skin];
  const pos = resolvePosition(skin);
  win = new BrowserWindow({
    width: w,
    height: h,
    x: pos.x,
    y: pos.y,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    resizable: false,
    maximizable: false,
    minimizable: false,
    fullscreenable: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    hasShadow: false,
    show: false,
    title: 'dsh-mmy-ttslive',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
      backgroundThrottling: false,
    },
  });
  win.setAlwaysOnTop(true, 'screen-saver');
  try {
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  } catch {
    // Windows 上不支持也无所谓，置顶已经够了
  }
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.once('ready-to-show', () => {
    win.showInactive();
    win.webContents.send('skin', skin);
    console.log(`[ttslive] 窗口就绪 skin=${skin} ${w}×${h} @ ${pos.x},${pos.y}`);
  });
  win.on('moved', () => {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      if (!win || win.isDestroyed()) return;
      const [x, y] = win.getPosition();
      saveState({ x, y });
    }, 400);
  });
  win.on('closed', () => {
    win = null;
  });
}

function applySkin(name) {
  if (!SKINS[name] || !win || win.isDestroyed()) return false;
  const old = win.getBounds();
  const { w, h } = SKINS[name];
  const cx = old.x + old.width / 2;
  const bottom = old.y + old.height;
  const x = Math.round(cx - w / 2);
  const y = Math.round(bottom - h);
  win.setBounds({ x, y, width: w, height: h });
  saveState({ skin: name, x, y });
  win.webContents.send('skin', name);
  broadcastSse({ type: 'skin', skin: name });
  return true;
}

// ---------- 事件广播 ----------
function broadcast(channel, payload) {
  if (win && !win.isDestroyed()) win.webContents.send(channel, payload);
}

function broadcastSse(event) {
  const line = `data: ${JSON.stringify(event)}\n\n`;
  for (const res of sseClients) {
    try {
      res.write(line);
    } catch {
      sseClients.delete(res);
    }
  }
}

function pushCaption(payload) {
  const text = String(payload?.text ?? '').trim();
  if (!text) return false;
  const total = Number(payload?.total) > 0 ? Math.round(Number(payload.total)) : 0;
  const index = Number(payload?.index) > 0 ? Math.round(Number(payload.index)) : 0;
  const hold = Number(payload?.hold) > 0 ? Math.round(Number(payload.hold)) : 0;
  broadcast('caption', { text, index, total, hold, at: Date.now() });
  broadcastSse({ type: 'caption', text, index, total, hold, at: Date.now() });
  return true;
}

// ---------- HTTP ----------
function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (c) => {
      raw += c;
      if (raw.length > 1_000_000) req.destroy();
    });
    req.on('end', () => {
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        resolve({ text: raw });
      }
    });
    req.on('error', reject);
  });
}

function json(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'content-type': 'application/json; charset=utf-8', 'content-length': Buffer.byteLength(body) });
  res.end(body);
}

function startServer() {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://127.0.0.1');
    const route = `${req.method} ${url.pathname}`;
    try {
      if (route === 'GET /health') {
        const b = win && !win.isDestroyed() ? win.getBounds() : null;
        return json(res, 200, {
          ok: true,
          skin: currentSkin(),
          port: httpPort,
          visible: Boolean(win && !win.isDestroyed() && win.isVisible()),
          bounds: b,
          sse: sseClients.size,
          state,
        });
      }
      if (route === 'GET /events') {
        res.writeHead(200, {
          'content-type': 'text/event-stream; charset=utf-8',
          'cache-control': 'no-cache',
          connection: 'keep-alive',
          'access-control-allow-origin': '*',
        });
        res.write(': connected\n\n');
        sseClients.add(res);
        req.on('close', () => sseClients.delete(res));
        return;
      }
      if (route === 'GET /screenshot') {
        if (!win || win.isDestroyed()) return json(res, 503, { ok: false, error: 'no window' });
        const img = await win.capturePage();
        const out = path.join(userDir, `screenshot-${Date.now()}.png`);
        fs.mkdirSync(userDir, { recursive: true });
        fs.writeFileSync(out, img.toPNG());
        return json(res, 200, { ok: true, path: out, width: img.getSize().width, height: img.getSize().height });
      }
      if (route === 'POST /caption') {
        const body = await readBody(req);
        const ok = pushCaption(body);
        return json(res, ok ? 200 : 400, { ok });
      }
      if (route === 'POST /clear') {
        if (win && !win.isDestroyed()) win.webContents.send('clear');
        broadcastSse({ type: 'clear' });
        return json(res, 200, { ok: true });
      }
      if (route === 'POST /skin') {
        const body = await readBody(req);
        const ok = applySkin(String(body?.name || '').toUpperCase());
        return json(res, ok ? 200 : 400, { ok, skin: currentSkin() });
      }
      if (route === 'POST /show' || route === 'POST /hide') {
        if (win && !win.isDestroyed()) {
          if (route.endsWith('/show')) win.showInactive();
          else win.hide();
        }
        return json(res, 200, { ok: true });
      }
      json(res, 404, { ok: false, error: 'not found' });
    } catch (err) {
      json(res, 500, { ok: false, error: String(err?.message || err) });
    }
  });

  const tryListen = (i) => {
    if (i >= PORT_CANDIDATES.length) {
      console.error('[ttslive] 7788-7791 都被占用，服务没起来');
      return;
    }
    const port = PORT_CANDIDATES[i];
    server.once('error', (err) => {
      if (err.code === 'EADDRINUSE') tryListen(i + 1);
      else console.error('[ttslive] HTTP 出错：', err.message);
    });
    server.listen(port, '127.0.0.1', () => {
      httpPort = port;
      fs.writeFileSync(portFile, String(port), 'utf8');
      console.log(`[ttslive] HTTP 就绪 http://127.0.0.1:${port}（端口已写 ${portFile}）`);
    });
  };
  tryListen(0);
}

// ---------- 生命周期 ----------
ipcMain.on('drag-mode', (_e, on) => {
  if (!win || win.isDestroyed()) return;
  win.setIgnoreMouseEvents(!on, { forward: true });
});

app.whenReady().then(() => {
  userDir = app.getPath('userData');
  stateFile = path.join(userDir, 'state.json');
  portFile = path.join(userDir, 'port.txt');
  fs.mkdirSync(userDir, { recursive: true });
  state = loadState();
  if (!SKINS[state.skin]) state.skin = DEFAULT_SKIN;
  createWindow();
  startServer();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  app.quit();
});
