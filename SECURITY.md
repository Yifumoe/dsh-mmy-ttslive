# 安全说明

这是一个**本地单机**的桌面字幕窗：`server.js` 只监听 `127.0.0.1`，没有鉴权，也不发 CORS 头。

## 报告问题

- 普通 bug / 装不上 → 开 issue（贴报错、Windows 版本、Node 版本）。
- 疑似安全问题（本机任意文件读写、提权、把接口暴露到局域网）→ 不要开公开 issue，
  走 GitHub 的 [Private vulnerability reporting](https://github.com/Yifumoe/dsh-mmy-ttslive/security/advisories/new)。

## 使用边界

- 不要把 7788–7791 端口转发、反向代理或放到公网：能连上端口的人就能往你屏幕上推任意文字。
- 接口只接受本机进程调用；浏览器页面受同源策略限制（无 CORS 头）。
- 窗口内容来自本机 TTS 文本，不加载网络内容；`assets/avatar.jpg` 只是本地展示素材。
- 仓库已公开；代码以 Apache-2.0 授权，但**没有**附带任何第三方字体或素材的再分发许可。
