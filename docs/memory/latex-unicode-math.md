---
name: latex-unicode-math
description: LaTeX 公式与正文数学禁用 Unicode 数学符号，必须用 LaTeX 命令（∘ ₂ 在界面字体缺字形导致渲染失败）
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e711c7f6-ffc9-46c7-b797-c45fe9a5b619
  modified: 2026-08-24T08:04:20.320Z
---

数学内容必须用 LaTeX 命令书写，禁止 Unicode 数学符号冒充数学：公式内 `· ∘ × − … ⊕ ≤ ≥ ≪ ≫` 写为 `\cdot \circ \times \cdots \oplus \le \ge \ll \gg`；正文中的数学（含 ∘、₂ 等）必须放入 `$...$`。

**Why**：2026-08-24 用户报告 `算术电路.md:222` 前缀运算公式渲染失败。根因：`(g_i, p_i) ∘ (g_j, p_j) = ...` 与 `log₂ N` 是纯文本 Unicode 符号（不在 `$` 内），Obsidian 从界面字体取字形——`∘`（U+2218）与下标数字 `₂`（U+2082）在该字体缺失 → 豆腐块。KaTeX 实测证明 `$...$` 内的同类符号虽能解析，但 `...` 渲染为字面三点（排版降级），仍应写 `\cdots`。中文正文中 `≥ ≤ × ≈` 属 GB2312 通用符号，界面字体全覆盖，可保留。

**How to apply**：写任何含数学的笔记时：(1) 数学一律入 `$...$`；(2) 运算符一律 LaTeX 命令；(3) 批量增改后跑缺陷类扫描（纯文本 ∘₂₁₀⊕≪≫ + 公式内 ·∘×−…⊕≤≥≪≫ + `$` 定界符平衡，排除反引号代码 span 与 `$(Makefile 变量)`）。相关：[[qa-pipeline]]、[[self-consistency-check]]。
