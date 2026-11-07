# 参与贡献

这是个很小的本地工具，改动门槛不高，但有几条硬约束。

## 环境

- Windows 10/11
- Node.js ≥ 18（服务端只用内置模块，**不需要 `npm install`**）
- Windows PowerShell 5.1 或 PowerShell 7（WPF 窗口）
- .NET Framework 4.7.2+（Win10/11 自带；`ttslive.ps1` 用 WPF）

## 改之前

```powershell
git clone https://github.com/Yifumoe/dsh-mmy-ttslive.git
cd dsh-mmy-ttslive
node --check server.js
node scripts/check-ascii.js
```

## 硬约束

1. **`ttslive.ps1` / `launch.ps1` 必须保持纯 ASCII**。PowerShell 5.1 读 UTF-8 无 BOM 会乱码，注释也写英文。`node scripts/check-ascii.js` 会拦。
2. **不要引入 npm 依赖**。服务端只用 `node:http` / `node:fs` / `node:path`。
3. **端口不要写死 7788**。实际端口在 `.cache/ttslive-port.txt`，窗口和服务都读它。
4. **A/B 两套皮肤要同步改**（`ui/skin-a.xaml` / `ui/skin-b.xaml`），颜色对齐 `tools/style-tokens.mjs` 的绫波丽冷调。
5. **不要提交** `state.json`、`.cache/`、`*.log`（已在 `.gitignore`）。

## 提交

- 中文 commit message，一条一个主题：`fix: ...` / `feat: ...` / `docs: ...` / `chore: ...`
- 改窗口行为请顺手在 README「坑」里补一句踩过的点
- 发 PR 前跑一遍 `npm run check`

## 报问题

- 跑不起来 / 字幕不同步 → 用 bug 模板，贴 `.cache/launch.log` 和 `.cache/ttslive.log`
- 安全问题 → 走 [私密报告](https://github.com/Yifumoe/dsh-mmy-ttslive/security/advisories/new)，别开公开 issue
