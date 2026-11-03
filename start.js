'use strict';
/**
 * 启动器：绕开 ELECTRON_RUN_AS_NODE。
 *
 * 有些环境（比如 DSH 的终端）会带 ELECTRON_RUN_AS_NODE=1，这时 electron.exe 会以
 * 纯 Node 模式跑，require('electron') 拿到的是路径字符串而不是 API，主进程直接崩。
 * 所以在 node 里 require('electron') 拿二进制路径，清掉这个变量再拉起来。
 */
const { spawn } = require('node:child_process');

const electronPath = require('electron');
const env = { ...process.env };
delete env.ELECTRON_RUN_AS_NODE;

const child = spawn(electronPath, ['--no-sandbox', '.', ...process.argv.slice(2)], {
  stdio: 'inherit',
  env,
  cwd: __dirname,
});

child.on('exit', (code) => process.exit(code ?? 0));
