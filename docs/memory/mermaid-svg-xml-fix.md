---
name: mermaid-svg-xml-fix
description: Mermaid 图经 msedge dump-dom 产出的 SVG 含裸 <br>（HTML 序列化），须转 <br/> 方为合法 XML；Obsidian 按 XML 加载 <img src=.svg>
metadata:
  type: feedback
---

Mermaid 图渲染为 .svg 资产时，若经浏览器 `--dump-dom` 提取（HTML DOM 序列化），void 元素 `<br>` 会以**无自闭合**形式输出——但 Obsidian/浏览器加载 `<img src=".svg">` 时按 **XML** 解析，裸 `<br>` 是永不闭合的开标签，导致整图加载失败（表现：图片裂开/空白，无报错提示）。

**Why:** 2026-09-08 实测——新渲染的 bitmap-lookup-twolevel.svg 9 处 `<br>` 加载失败；库内正常老图（async-fifo-architecture.svg）全部为 `<br />` 自闭合形态。mermaid v10 ESM module 在 file:// 下无法执行（需 v9 UMD classic script 或转义规避），v9 经 dump-dom 序列化即产裸 `<br>`。

**How to apply:** 渲染管线已固化为 **`tools/render_mermaid.sh`**（2026-09-08，与 render_wavedrom.sh 同构）：浏览器探测（CHROME 环境变量 → puppeteer 缓存 → Windows msedge/chrome 常见路径）→ 本地 mermaid@9.4.3 UMD（首次下载 `~/.cache/mermaid-9.4.3/`，锁定 v9——v10 ESM 在 `file://` 下无法执行）→ node 以 JSON.stringify 内嵌 mmd 生成临时渲染页 → `--headless --dump-dom --virtual-time-budget=15000` → node 正则提取 `<svg>…</svg>` → **必须后处理 `<br>` → `<br/>`**（正则 `<br(?![^>]*\/>)` 防重复）→ 对产物 .svg 二次 dump 验证 XML 良构 → 输出 OK。已验证确定性：同一 .mmd 两次渲染字节一致。CLAUDE.md 规则 12 亦适用：命令行禁字面中文，脚本内容本身经文件承载无碍。
