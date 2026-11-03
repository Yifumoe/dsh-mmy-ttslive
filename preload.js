'use strict';
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('ttslive', {
  onCaption: (fn) => ipcRenderer.on('caption', (_e, d) => fn(d)),
  onSkin: (fn) => ipcRenderer.on('skin', (_e, d) => fn(d)),
  onClear: (fn) => ipcRenderer.on('clear', () => fn()),
  dragMode: (on) => ipcRenderer.send('drag-mode', Boolean(on)),
});
