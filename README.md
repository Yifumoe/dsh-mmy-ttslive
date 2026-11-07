# dsh-mmy-ttslive · 台词悬浮窗

## 是什么

把本地 TTS 正在播的**每一段**同步显示成桌面字幕。无边框、置顶、可缩放的小窗，两套皮肤，风格沿用绫波丽冷调。

服务端只用 Node 内置模块（**不需要 `npm install`**），窗口是 PowerShell + WPF，仅 Windows。

- **A · 通栏条幅**：960×118，底部居中。安静，最像字幕。
- **B · 悬浮卡**：720×190，带编号、时间、网格底纹与段进度。
- 说话时展开；念完约 3 秒后收成 34px 待机条（尾部字幕仍在），鼠标移入即展开；拖过的位置会记住。
- 历史在右键控制面板的「历史记录」或托盘菜单里看，不是滚轮翻页。
- 8 方向边缘缩放（7px 内是缩放、不是拖窗；最小 420×64）。
- 被关掉不用手动开：`say.js` 说话前探一次 `/health`（60 秒内只探一次），不在就跑 `launch.ps1` 拉起来。设置页「语音 → 台词悬浮窗」总开关为 0 时整条链路不碰。

> 语音合成本体在 [dsh-genie-tts](https://github.com/Yifumoe/dsh-genie-tts)：`say.py` 每段合成完把台词 POST 给这里。只用语音、不要字幕窗也完全没问题；这个仓库只负责显示。

## 跑起来

```powershell
# 幂等启动：只补没起的部分（先 server.js，再 WPF 窗口）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launch.ps1
```

前提：`node` 在 PATH（或设 `TTSLIVE_NODE` 指向 node.exe），WPF 窗口需要 Windows PowerShell 5.1 / pwsh 7。`launch.ps1` 用脚本自身目录，不绑死盘符。

只想起接口层：`node server.js`；只重开窗口：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ttslive.ps1`；`npm start` 等价于 `.\launch.ps1`（不需要 `npm install`，没有依赖）。

DSH 里正常不用手动：`mmy_say` 说话前会自动拉起。端口默认 `7788`，被占用顺延 `7789/7790/7791`，实际端口写进 `.cache/ttslive-port.txt`；`launch.ps1` 先读这个文件再探活，不会在端口顺延后又拉起第二个 server。

## 接口（server.js，只监听 127.0.0.1）

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/health` | `{ok, seq, skin}`，给 `say.js` 探活 |
| GET | `/next?since=N` | 窗口**短轮询**（每 220ms）：有新段 `{has:true, seq, text, index, total, prev, next, duration, breaks, speed, live, ts}`；没有则 `{has:false, seq}` |
| GET | `/history?limit=N` | `{items:[{seq, text, index, total, ts}], total}`；默认 20，上限 **60** |
| POST | `/caption` | 入队一段：`{text, index?, total?, duration?, prev?, next?, breaks?, speed?}` → `{ok, seq}`；`text` 为空返回 400 |
| POST | `/clear` | 播放结束：`live=false` 且 `seq+1`，文本留在屏幕上 |
| GET/POST | `/skin` | POST `{skin:"a"\|"b"}`，GET 返回 `{skin}`；兼容保留，**WPF 窗口不消费**，切皮肤用右键面板/托盘 |
| GET | `/state` | `{skin, seq, text, index, total, live, historyTotal}`，窗口启动时对齐 `seq` 用 |

`breaks` 是句内停顿切点（0–1 比例），驱动字幕的波浪/进度轴；`speed` 用来对齐字速（默认 1.12）。

接口**没有鉴权**，只绑 `127.0.0.1`；不发 CORS 头，浏览器网页不能跨源往里推字幕，但本机任意进程仍可发 HTTP，别把端口转发到局域网。

## 装完怎么验收

1. `.\launch.ps1` 后 `Invoke-RestMethod http://127.0.0.1:7788/health` 返回 `ok: True`（端口以 `.cache/ttslive-port.txt` 为准）。
2. `Invoke-RestMethod -Method Post -Uri http://127.0.0.1:7788/caption -ContentType 'application/json' -Body '{"text":"验收一句","index":1,"total":1}'` → 窗口出现字幕、`/state` 的 `seq` 加 1。
3. `Invoke-RestMethod -Method Post -Uri http://127.0.0.1:7788/clear` → `live: False`，文字留在屏上，约 3 秒后收成待机条。

> 上面是 PowerShell 原生写法。在 Git Bash / cmd 里请用 `curl.exe`（不是 `curl`，PowerShell 里 `curl` 是 `Invoke-WebRequest` 的别名，`-X` 会报「找不到与参数名称 X 匹配的参数」）。
4. 把窗口拖到屏幕最下沿再重启窗口，确认整条仍在屏内、不会只剩顶边（125% 缩放下也要试）。
5. 从 Git Bash 跑 `.\launch.ps1` 报「无法加载文件」时用 `powershell.exe -ExecutionPolicy Bypass -File .\launch.ps1`，不是脚本坏了。

## 和 TTS 接线

窗口不知道音频怎么播，它只收「现在该显示哪一句」。接法只有一处：**每段音频开始时 POST 一次 `/caption`**。

本机链路（下面这些文件在宿主工作区 `D:\DSH-MMYMOE`，**不在本仓库**）：

1. `mmy-life/resources/voice/say.py` 按句切段、逐句合成播放，后台队列把每段 POST 到 `/caption`（端口先读 `.cache/ttslive-port.txt`，再依次试 7788–7791）；
2. `mmy-life/lib/core/say.js` 只负责说话前探活：`/health` 60 秒内只探一次，不通就跑 `launch.ps1` 拉起来；
3. 窗口显示；念完约 3 秒收成 34px 待机条，下一段来了直接展开换字。

## 目录

```
ttslive.ps1          WPF 窗口主体：皮肤、控制面板、历史窗、8 方向缩放（保持纯 ASCII）
server.js            端口 7788 的 HTTP：/caption 入队，窗口 /next 短轮询
launch.ps1           幂等启动脚本（先 server 后窗口；用自身目录，node 可用 TTSLIVE_NODE 覆盖）
ui/skin-a.xaml       皮肤 A
ui/skin-b.xaml       皮肤 B
ui/menu.xaml         右键控制面板
assets/avatar.jpg    窗内头像 / 托盘图标（换成自己的图即可）
state.json           窗口位置、皮肤、透明度（运行时生成，已 gitignore）
```

早期还有一个 Electron 试验版（主进程 / 渲染层）和一批一次性调试脚本（`click-*` / `probe-*` / `test-*` / `launch-wmi.ps1` 等），**2026-11-04 已删除**——它们不参与现行链路、硬编码本机路径，`npm start` 还会走错路线。需要看旧实现就翻 git 历史（`ce664f3` 之后、`6c91252` 之前）。

## 设计

颜色、字号沿用宿主工作区的 `tools/style-tokens.mjs`（绫波丽冷调；不在本仓库），实际落点是 `ui/skin-a.xaml` / `ui/skin-b.xaml`：

- 底：A `#F4F9FC` / B `#F7FBFD`；主色 `#176B91`，深字 `#0D4F68`
- 文本 `#203849` / `#476173` / `#556C7F`（小字，对 `#F4F9FC` 对比度 5.16:1）；次要提示 `#5A7286`（4.74:1）
- 窗口每 5 秒写一次 `.cache/window-alive.txt` 心跳；宿主 `say.js` 靠它区分「服务活着但窗口被关了」，好重新拉起
- 发丝线一律青蓝 alpha（`#28698A0F` / `#28698A30` / `#28698A40`），不用中性灰；直角不用圆角，靠发丝线分层不靠投影
- `renderer/styles.css` 里那套 `#EFF6FA` / `#FAFDFE` 是旧 Electron 试验用色（相关文件已移除），不代表现行窗口

改风格：A/B 两套 `ui/*.xaml` 要同步；`tools/style-tokens.mjs` 反向对齐即可，别只改一边。

## 版本与许可

- 版本 `0.1.0`；代码以 **Apache-2.0** 授权，全文见 [LICENSE](LICENSE)。仓库目前是 private，但不影响授权条款。
- 变更看 `git log`（暂不放 CHANGELOG）。
- `assets/avatar.jpg` 是本机头像素材，可替换；公开前确认你愿意把它一起公开。
- 安全问题怎么报、使用边界（只监听 127.0.0.1、无鉴权）见 [SECURITY.md](SECURITY.md)。

## 坑（都踩过）

- **子进程不能 `detached: true`**：Windows 的 `DETACHED_PROCESS` 下 powershell.exe 拿不到控制台，会静默 `exit 0`，脚本一行都不跑、日志也不写。用 `windowsHide: true` 即可。2026-11-03 踩过一次，`say.js` 的自动拉起一度完全失效。
- `ttslive.ps1` 必须保持纯 ASCII（PowerShell 5.1 读 UTF-8 无 BOM 会乱码）。
- `server.js` 和窗口都靠 `.cache/ttslive-port.txt` 对齐端口；端口顺延后不要硬编码 7788。
- `/next` 是 220ms 短轮询不是长轮询；改协议时 `server.js` 与 `ttslive.ps1` 的 `$timer` 段要一起改，否则窗口会一直显示旧段。
- 鼠标穿透（`WS_EX_TRANSPARENT`）未做；待机条只有 34px，暂不挡事。
- 启动时别用 `Start-Process powershell` 直拉窗口（某些终端会留黑框）；`launch.ps1` 里已改成 `Start-Process -WindowStyle Hidden`。
