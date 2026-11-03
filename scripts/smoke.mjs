/**
 * 冒烟自检：假设悬浮窗已经在跑。
 *
 *   node scripts/smoke.mjs
 *
 * 干三件事：① 从 port.txt 找端口并 /health ② POST 一段字幕 ③ 截图并校验 PNG 非空。
 * 退出码 0 = 通过；非 0 时打印哪一步挂了。
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const USER_DIR = path.join(process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming'), 'dsh-mmy-ttslive');
const PORT_FILE = path.join(USER_DIR, 'port.txt');

function fail(msg) {
  console.error('❌', msg);
  process.exit(1);
}

if (!fs.existsSync(PORT_FILE)) fail(`没找到端口文件 ${PORT_FILE}（应用没起过？）`);
const port = fs.readFileSync(PORT_FILE, 'utf8').trim();
if (!/^\d+$/.test(port)) fail(`端口文件内容不对：${port}`);

const base = `http://127.0.0.1:${port}`;

const health = await fetch(`${base}/health`).then((r) => r.json()).catch((e) => fail(`/health 连不上：${e.message}`));
if (!health.ok) fail(`/health 返回不正常：${JSON.stringify(health)}`);
console.log(`✅ health：skin=${health.skin} visible=${health.visible} bounds=${JSON.stringify(health.bounds)}`);

const text = '冒烟自检：这段话应当出现在悬浮窗里，念完自己淡出。';
const post = await fetch(`${base}/caption`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ text, index: 1, total: 3, hold: 6000 }),
}).then((r) => r.json()).catch((e) => fail(`POST /caption 失败：${e.message}`));
if (!post.ok) fail(`POST /caption 返回 ${JSON.stringify(post)}`);
console.log('✅ caption 已推');

await new Promise((r) => setTimeout(r, 600));
const shot = await fetch(`${base}/screenshot`).then((r) => r.json()).catch((e) => fail(`/screenshot 失败：${e.message}`));
if (!shot.ok || !fs.existsSync(shot.path)) fail(`截图没生成：${JSON.stringify(shot)}`);
const size = fs.statSync(shot.path).size;
if (size < 3000) fail(`截图太小（${size} B），窗口可能是空的`);
console.log(`✅ 截图 ${shot.width}×${shot.height}，${(size / 1024).toFixed(1)} KB → ${shot.path}`);

await fetch(`${base}/clear`, { method: 'POST' }).catch(() => {});
console.log('全部通过');
