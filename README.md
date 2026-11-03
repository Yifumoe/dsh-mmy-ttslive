# dsh-mmy-ttslive · 台词悬浮窗

把本地 TTS 正在播的**每一段**同步显示成桌面字幕。无边框、置顶、可缩放的小窗，两套皮肤，风格沿用绫波丽冷调。

- **A · 通栏条幅**：960×118，底部居中。安静，最像字幕。
- **B · 悬浮卡**：720×190，带编号、时间、网格底纹与段进度。
- 说话时展开，念完停在屏幕上不消失；往上翻能看到历史；拖过的位置会记住。
- 8 方向边缘缩放（7px 内是缩放、不是拖窗）。
- 被关掉不用手动开：`say.js` 每次说话前探一次 `/health`，不在就跑 `launch.ps1` 拉起来。设置页「语音 → 台词悬浮窗」总开关为 0 时整条链路不碰。

## 跑起来

```bash
# 幂等启动：只补没起的部分（先 server.js，再 WPF 窗口）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\DSH-MMYMOE\dsh-mmy-ttslive\launch.ps1
```

DSH 里正常不用手动：`mmy_say` 说话前会自动拉起。端口默认 `7788`，被占用顺延 `7789/7790/7791`，实际端口写进 `.cache/ttslive-port.txt`。

## 接口（server.js，只监听 127.0.0.1）

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/health` | `{ok, seq, skin}`，给 `say.js` 探活 |
| GET | `/next?since=N` | 窗口长轮询：有新段返回 `{has, text, index, total, duration, breaks, ...}` |
| GET | `/history?limit=N` | 最近 N 段历史（默认 20，上限 200） |
| POST | `/caption` | 推一段字幕：`{text, index?, total?, duration?, prev?, next?, breaks?, speed?}` |
| POST | `/clear` | 播放结束：`live=false`，文本留在屏幕上 |
| POST | `/skin` | `{skin:"a"|"b"}` 切皮肤 |

`breaks` 是句内停顿切点（0–1 比例），驱动字幕的波浪/进度轴；`speed` 用来对齐字速。

## 和 TTS 接线

窗口不知道音频怎么播，它只收「现在该显示哪一句」。接法只有一处：**每段音频开始时 POST 一次 `/caption`**。

本机链路：

1. `resources/voice/say.py` 按句切段、逐句合成播放，打印 `[say] 第 N/M 段：<文本>`；
2. `mmy-life/lib/core/say.js` 解析这行，POST 到 `/caption`；
3. 窗口显示，念完自动淡出/更新，下一段来了直接换。

## 目录

```
ttslive.ps1          WPF 窗口主体：皮肤、控制面板、历史窗、8 方向缩放（保持纯 ASCII）
server.js            端口 7788 的 HTTP：/caption 入队，窗口 /next 长轮询
launch.ps1           幂等启动脚本（先 server 后窗口）
ui/skin-a.xaml       皮肤 A
ui/skin-b.xaml       皮肤 B
ui/menu.xaml         控制面板
click-skin.ps1       控制面板按钮的 UIA 点击辅助
renderer/            早期 Electron 试验（已判死，保留参考）
```

## 设计

颜色、字号与 `D:\DSH-MMYMOE\tools\style-tokens.mjs`（绫波丽冷调）一致：

- 底 `#EFF6FA` / 面 `#FAFDFE`，主色 `#176B91`
- 文本 `#203849` / `#476173` / `#718998`
- 发丝线一律青蓝 alpha（`#28698a29`），不用中性灰；直角不用圆角，靠发丝线分层不靠投影

改风格：先改 `tools/style-tokens.mjs`，再同步 `ui/*.xaml` 与 `renderer/styles.css`。

## 坑（都踩过）

- **子进程不能 `detached: true`**：Windows 的 `DETACHED_PROCESS` 下 powershell.exe 拿不到控制台，会静默 `exit 0`，脚本一行都不跑、日志也不写。用 `windowsHide: true` 即可。2026-11-03 踩过一次，`say.js` 的自动拉起一度完全失效。
- `ttslive.ps1` 必须保持纯 ASCII（PowerShell 5.1 读 UTF-8 无 BOM 会乱码）。
- 鼠标穿透（`WS_EX_TRANSPARENT`）未做；待机条只有 34px，暂不挡事。
- 启动时别用 `Start-Process powershell` 直拉窗口（某些终端会留黑框）；`launch.ps1` 里已改成 `Start-Process -WindowStyle Hidden`。
