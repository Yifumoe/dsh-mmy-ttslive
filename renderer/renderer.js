'use strict';
// 渲染进程：只管显示。文字从主进程 via preload 推过来，一段一换。
const stage = document.getElementById('stage');
const txA = document.getElementById('txA');
const txB = document.getElementById('txB');
const progA = document.getElementById('progA');
const progB = document.getElementById('progB');
const segB = document.getElementById('segB');
const noB = document.getElementById('noB');
const tmB = document.getElementById('tmB');

let hideTimer = null;
let lastIndex = 0;
let lastTotal = 0;

const pad2 = (n) => String(n).padStart(2, '0');

/** 收得太长就缩字号，缩到下限还放不下就交给 overflow 裁（宁可少一句，不压字重叠）。 */
function fitText(el, base, min, maxH) {
  let size = base;
  el.style.fontSize = size + 'px';
  let guard = 0;
  while (el.scrollHeight > maxH + 1 && size > min && guard < 60) {
    size -= 1;
    el.style.fontSize = size + 'px';
    guard += 1;
  }
}

function setSkin(name) {
  document.body.dataset.skin = name === 'B' ? 'B' : 'A';
}

function show(payload) {
  const text = String(payload?.text || '').trim();
  if (!text) return;
  const index = Number(payload?.index) > 0 ? Math.round(Number(payload.index)) : lastIndex;
  const total = Number(payload?.total) > 0 ? Math.round(Number(payload.total)) : lastTotal;
  lastIndex = index;
  lastTotal = total;

  txA.textContent = text;
  txB.textContent = text;
  fitText(txA, 20, 14, 60);
  fitText(txB, 21, 15, 102);

  const pct = total > 0 && index > 0 ? Math.min(100, Math.round((index / total) * 100)) : 0;
  progA.style.width = pct + '%';
  progB.style.width = pct + '%';
  segB.textContent = total > 0 ? `第 ${index} / ${total} 段` : '台词';
  noB.textContent = 'EVE·' + String(index || 0).padStart(4, '0');
  const d = new Date();
  tmB.textContent = `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;

  stage.classList.add('on');
  window.ttslive.dragMode(true); // 有字时才接鼠标：平时不挡桌面，字幕在的时候能拖
  clearTimeout(hideTimer);
  const hold = Number(payload?.hold) > 0 ? Number(payload.hold) : Math.max(2600, text.length * 240);
  hideTimer = setTimeout(() => {
    stage.classList.remove('on');
    window.ttslive.dragMode(false);
  }, hold);
}

function clear() {
  clearTimeout(hideTimer);
  stage.classList.remove('on');
  window.ttslive.dragMode(false);
}

window.ttslive.onSkin(setSkin);
window.ttslive.onCaption(show);
window.ttslive.onClear(clear);
