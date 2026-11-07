# dsh-mmy-ttslive · 台词悬浮窗

[![platform](https://img.shields.io/badge/platform-Windows%2010%2F11-176B91)](https://github.com/Yifumoe/dsh-mmy-ttslive)
[![node](https://img.shields.io/badge/node-%E2%89%A518-176B91)](https://nodejs.org/)
[![deps](https://img.shields.io/badge/dependencies-0-176B91)](package.json)
[![license](https://img.shields.io/badge/license-Apache--2.0-176B91)](LICENSE)

把本地 TTS 正在播的**每一段**同步显示成桌面字幕。无边框、置顶、可缩放的小窗，两套皮肤，风格沿用绫波丽冷调。

![皮肤 A · 通栏条幅](assets/preview-a.png)

![皮肤 B · 悬浮卡](assets/preview-b.png)

> 上面两张是加载仓库里真实的 `ui/skin-a.xaml` / `ui/skin-b.xaml` 离屏渲染的，不是画的示意图。

## 是什么

服务端只用 Node 内置模块（**不需要 `npm install`**），窗口是 PowerShell + WPF，**仅 Windows**。

- **A · 通栏条幅**：960×118，底部居中。安静，最像字幕。
- **B · 悬浮卡**：720×190，带编号、时间、网格底纹与段进度。
- 说话时展开；念完约 3 秒后收成 34px 待机条（尾部字幕仍在），鼠标移入即展开；拖过的位置会记住。
- 历史在右键控制面板的「历史记录」或托盘菜单里看，不是滚轮翻页。
- 8 方向边缘缩放（7px 内是缩放、不是拖窗；最小 420×64）。
- 被关掉不用手动开：`say.js` 说话前探一次 `/health`（60 秒内只探一次），不在就跑 `launch.ps1` 拉起来。设置页「语音 → 台词悬浮窗」总开关为 0 时整条链路不碰。

> 语音合成本体在 [dsh-genie-tts](https://github.com/Yifumoe/dsh-genie-tts)：`say.py` 每段合成完把台词 POST 给这里。只用语音、不要字幕窗也完全没问题；这个仓库只负责显示。

## 快速开始（从 clone 到看到字幕）

前提：Windows 10/11、Node.js ≥ 18、Windows PowerShell 5.1（系统自带）。WPF 依赖 **.NET Framework 4.7.2+**，Win10 1803 之后系统自带，不用单独装；用 PowerShell 7 的话需要装 .NET 桌面运行时。

```powershell
git clone https://github.com/Yifumoe/dsh-mmy-ttslive.git
cd dsh-mmy-ttslive

# 1. 起服务 + 窗口（幂等，重复跑只补没起的部分）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launch.ps1

# 2. 读实际端口（7788 被占用会顺延到 7789–7791）
$port = (Get-Content .\.cache\ttslive-port.txt).Trim()

# 3. 推一句字幕
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$port/caption" `
  -ContentType 'application/json' -Body '{"text":"你好，字幕窗","index":1,"total":1}'

# 4. 结束播放（文字留在屏上，约 3 秒后收成待机条）
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$port/clear"
```

窗口没出现先看 `.cache\launch.log` 和 `.cache\ttslive.log`。

## 跑起来

```powershell
# 幂等启动：只补没起的部分（先 server.js，再 WPF 窗口）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launch.ps1
```

前提：`node` 在 PATH（或设 `TTSLIVE_NODE` 指向 node.exe），WPF 窗口需要 Windows PowerShell 5.1 / pwsh 7。`launch.ps1` 用脚本自身目录，不绑死盘符；找不到 node 时会依次试 PATH、`%ProgramFiles%\nodejs`、`%ProgramFiles(x86)%\nodejs`、`%LOCALAPPDATA%\Programs\nodejs`。

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

## 和 TTS 接线

窗口不知道音频怎么播，它只收「现在该显示哪一句」。接法只有一处：**每段音频开始时 POST 一次 `/caption`**。

任何语言都能接，端口从 `.cache/ttslive-port.txt` 读（不要写死 7788）：

```bash
# Git Bash / cmd：用 curl.exe，不是 PowerShell 里的 curl 别名
PORT=$(cat .cache/ttslive-port.txt)
curl.exe -s -X POST "http://127.0.0.1:$PORT/caption" \
  -H "Content-Type: application/json" \
  -d '{"text":"这一句要显示的字幕","index":1,"total":3}'
```

```python
# Python（标准库，无依赖）
import json, pathlib, urllib.request
port = pathlib.Path(".cache/ttslive-port.txt").read_text().strip()
req = urllib.request.Request(
    f"http://127.0.0.1:{port}/caption",
    data=json.dumps({"text": "这一句要显示的字幕", "index": 1, "total": 3}).encode(),
    headers={"Content-Type": "application/json"},
)
urllib.request.urlopen(req, timeout=2).read()
```

本机 DSH 链路（下面这些文件在宿主工作区 `D:\DSH-MMYMOE`，**不在本仓库**，只是举例）：

1. `mmy-life/resources/voice/say.py` 按句切段、逐句合成播放，后台队列把每段 POST 到 `/caption`（端口先读 `.cache/ttslive-port.txt`，再依次试 7788–7791）；
2. `mmy-life/lib/core/say.js` 只负责说话前探活：`/health` 60 秒内只探一次，不通就跑 `launch.ps1` 拉起来；
3. 窗口显示；念完约 3 秒收成 34px 待机条，下一段来了直接展开换字。

## 配皮肤

1. **运行时切**：右键窗口 → 控制面板里选 A / B；或托盘图标右键 → 皮肤。选择会写进 `state.json`，下次启动沿用。
2. **改样式**：直接改 `ui/skin-a.xaml` / `ui/skin-b.xaml`。两套要同步改，别只改一边。
3. **颜色**：对齐宿主工作区 `tools/style-tokens.mjs` 的绫波丽冷调（不在本仓库）。现行落点：
   - 底：A `#F4F9FC` / B `#F7FBFD`；主色 `#176B91`，深字 `#0D4F68`
   - 文本 `#203849` / `#476173` / `#556C7F`（小字，对 `#F4F9FC` 对比度 5.16:1）；次要提示 `#5A7286`（4.74:1）
   - 发丝线一律青蓝 alpha（`#28698A0F` / `#28698A30` / `#28698A40`），不用中性灰；直角不用圆角，靠发丝线分层不靠投影
4. 改完重开窗口：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ttslive.ps1`（先关掉旧窗口）。

## 停止 / 卸载

- **只关窗口**：右键面板「退出」或托盘「退出」。服务还在，下次说话会自动重开窗口。
- **连服务一起停**：

  ```powershell
  $port = (Get-Content .\.cache\ttslive-port.txt).Trim()
  Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object { Stop-Process -Id $_ -Force }
  ```

- **卸载**：没有安装器、不写注册表、不开机自启。停掉进程后直接删掉仓库目录即可；如果设过 `TTSLIVE_NODE` 环境变量，顺手删掉。宿主 `say.js` 的自动拉起是宿主侧行为，不在本仓库，卸载后它探不到服务会自己跳过。

## 目录

```
ttslive.ps1          WPF 窗口主体：皮肤、控制面板、历史窗、8 方向缩放（保持纯 ASCII）
server.js            端口 7788 的 HTTP：/caption 入队，窗口 /next 短轮询
launch.ps1           幂等启动脚本（先 server 后窗口；用自身目录，node 可用 TTSLIVE_NODE 覆盖）
ui/skin-a.xaml       皮肤 A
ui/skin-b.xaml       皮肤 B
ui/menu.xaml         右键控制面板
assets/avatar.jpg    窗内头像 / 托盘图标（换成自己的图即可）
assets/preview-*.png README 截图（由 ui/*.xaml 离屏渲染）
scripts/check-ascii.js  自检：两个 ps1 必须纯 ASCII
state.json           窗口位置、皮肤、透明度（运行时生成，已 gitignore）
```

早期还有一个 Electron 试验版（主进程 / 渲染层）和一批一次性调试脚本（`click-*` / `probe-*` / `test-*` / `launch-wmi.ps1` 等），**2026-11-04 已删除**——它们不参与现行链路、硬编码本机路径，`npm start` 还会走错路线。需要看旧实现就翻 git 历史（`ce664f3` 之后、`6c91252` 之前）。

## 设计

颜色、字号沿用宿主工作区的 `tools/style-tokens.mjs`（绫波丽冷调；不在本仓库），实际落点是 `ui/skin-a.xaml` / `ui/skin-b.xaml`。要点见上面「配皮肤」。

- 窗口每 5 秒写一次 `.cache/window-alive.txt` 心跳；宿主 `say.js` 靠它区分「服务活着但窗口被关了」，好重新拉起
- 改风格：A/B 两套 `ui/*.xaml` 要同步；`tools/style-tokens.mjs` 反向对齐即可，别只改一边

## 版本与许可

- 版本 `0.1.0`；代码以 **Apache-2.0** 授权，全文见 [LICENSE](LICENSE)。仓库已公开。
- 变更看 [CHANGELOG.md](CHANGELOG.md)。
- `assets/avatar.jpg` 是本机头像素材，随仓库一起公开；换成自己的图即可，替换前确认你有权使用。
- 社交预览图在 `assets/social-preview.png`（1280×640），在仓库 Settings → Social preview 上传后生效。
- 安全问题怎么报、使用边界（只监听 127.0.0.1、无鉴权）见 [SECURITY.md](SECURITY.md)。
- 想改代码看 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 坑（都踩过）

- **子进程不能 `detached: true`**：Windows 的 `DETACHED_PROCESS` 下 powershell.exe 拿不到控制台，会静默 `exit 0`，脚本一行都不跑、日志也不写。用 `windowsHide: true` 即可。2026-11-03 踩过一次，`say.js` 的自动拉起一度完全失效。
- `ttslive.ps1` 必须保持纯 ASCII（PowerShell 5.1 读 UTF-8 无 BOM 会乱码）。`node scripts/check-ascii.js` 会拦。
- `server.js` 和窗口都靠 `.cache/ttslive-port.txt` 对齐端口；端口顺延后不要硬编码 7788。
- `/next` 是 220ms 短轮询不是长轮询；改协议时 `server.js` 与 `ttslive.ps1` 的 `$timer` 段要一起改，否则窗口会一直显示旧段。
- 鼠标穿透（`WS_EX_TRANSPARENT`）已做，托盘/右键面板可切；穿透状态下点不到窗口，先切回来再操作。
- 启动时别用 `Start-Process powershell` 直拉窗口（某些终端会留黑框）；`launch.ps1` 里已改成 `Start-Process -WindowStyle Hidden`。
