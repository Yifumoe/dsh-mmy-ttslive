const fs = require('node:fs');
const LOG = 'D:/DSH-MMYMOE/.cache/ttslive-test.log';
const log = (m) => fs.appendFileSync(LOG, `[${new Date().toISOString()}] ${m}\n`);
log('boot pid=' + process.pid);
process.on('uncaughtException', (e) => log('EXC ' + (e && e.stack)));
log('before require electron');
const { app, BrowserWindow } = require('electron');
log('after require electron, app=' + typeof app);
app.on('child-process-gone', (_e, d) => log('child-gone ' + JSON.stringify(d)));
app.on('render-process-gone', (_e, _w, d) => log('render-gone ' + JSON.stringify(d)));
app.on('gpu-process-crashed', (_e, k) => log('gpu-crashed ' + k));
app.whenReady().then(() => {
  log('READY');
  const w = new BrowserWindow({ width: 400, height: 200 });
  log('WINDOW created');
  w.loadURL('data:text/html,<h1>ok</h1>');
  setTimeout(() => { log('QUIT'); app.quit(); }, 2500);
}).catch((e) => log('READY FAIL ' + e));
