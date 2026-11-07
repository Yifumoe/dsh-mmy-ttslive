// 仓库自检：PowerShell 脚本必须保持纯 ASCII（PowerShell 5.1 读 UTF-8 无 BOM 会乱码）。
// 用法：node scripts/check-ascii.js
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const targets = ['launch.ps1', 'ttslive.ps1'];
let failed = false;

for (const name of targets) {
  const file = path.join(root, name);
  const buf = fs.readFileSync(file);
  const bad = [];
  let line = 1;
  for (let i = 0; i < buf.length; i++) {
    const b = buf[i];
    if (b === 0x0a) line++;
    if (b > 0x7f) bad.push(line);
  }
  if (bad.length) {
    failed = true;
    const uniq = [...new Set(bad)];
    console.error(`${name}: 含非 ASCII 字节，行 ${uniq.join(', ')}`);
  } else {
    console.log(`${name}: ASCII OK`);
  }
}

if (failed) process.exit(1);
