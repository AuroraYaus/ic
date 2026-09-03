---
name: markdown-bold-flanking
description: 加黑 ** 定界符与标点相邻会使 CommonMark 加黑失效渲染裸 **——全库已修复 88 处
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ec9a0039-11b8-4f25-a678-f5b356dc34c0
  modified: 2026-08-29T08:56:48.356Z
---

用户指出 `asic-flow/concepts/功耗分析.md` 渲染后仍有裸 `**`。根因：`**开关功耗（Switching Power）**是` 这类写法中，闭合 `**` 前一字符是全角 `）`（标点）且后随汉字——CommonMark 定界规则下闭合符不成立，加黑失效、`**` 原样显示；开启 `**` 后一字符是标点同理（如 `的**"中端"环节与岗位**`）。

**Why:** Obsidian 宽松解析器能容忍，但 GitHub/Gitee 预览与严格 CommonMark 渲染器会显示裸 `**`；用户通过远端仓库渲染发现。多对加黑同处一行时还会交叉配对导致错误加黑范围——pandoc 无残留 `**` 也不能证明正确，必须按定界规则逐对扫描。

**How to apply:** 术语加黑一律 `**中文**（English, ABBR）`——英文括注放加黑外；闭合 `**` 前一字符、开启 `**` 后一字符不得与标点相邻。批量修复脚本教训：for 循环中修改 `line` 变量必须写回 `lines[i]`，否则写盘的是原内容、修复计数是假象。规则已登记 ic/CLAUDE.md §5（含近似 grep 与权威扫描说明）。关联 [[qa-enumeration-expansion]]。
