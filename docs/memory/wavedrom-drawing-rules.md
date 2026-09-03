---
name: wavedrom-drawing-rules
description: Wavedrom 绘制规则——连续同电平必须用 . 重复（显式重复出边界尖刻）、data 标签只挂 2/3 字符、= 是总线字符、data 框后需显式电平终止、json 改完必须重渲染
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ef9f9e62-75f2-4e64-99c2-30008c560696
  modified: 2026-09-02T09:48:34.207Z
---

用户指出 `reset-synchronizer-timing.svg` 波形有问题，系统排查（解码 SVG 图元序列）后确认并修复三类错误，同时总结出五条 Wavedrom 绘制规则：

1. **连续同电平必须用 `.` 重复**：`1000000x1111` 这种显式重复会在每个周期边界渲染出尖刻（0m0/1m1 图元）——应写 `10.....x1...`；`.` 只在电平变化时写新字符。
2. **`data` 标签只挂 `2`（低带标签）/`3`（高带标签）**：挂在 `x` 上不渲染、挂在 `=` 上渲染错电平（async-fifo 的 rempty 曾用 `=` 挂"撤销"标签，波形却不下降）。
3. **`=` 是总线值字符**，单比特标志信号禁用。
4. **data 字符后的 `.` 连数据框一起重复**：`2....` 会让数据框拖满整个段——框后要写显式电平字符（`...20...`）终止。
5. **`.json` 是唯一事实源**：改完必须 `tools/render_wavedrom.sh` 重渲染 `.html`+`.svg`（chrome headless + 本地 wavedrom 2.6.8 缓存于 ~/.cache/wavedrom-2.6.8），生成后解析 SVG 验证电平序列。

**Why:** 用户通过 Obsidian 目检发现波形尖刻；Wavedrom 渲染语义与直觉不同（显式重复≠连续线、data 框会随 `.` 扩散）；此前 .svg 是陈旧渲染（与 .json 不同步），三件套版本漂移导致图与源不符。

**How to apply:** 写 Wavedrom JSON 先按五条规则自查；改完跑渲染脚本并用图元解码脚本验证（每 lane 字符数与电平序列、无 0m0/1m1 尖刻图元）。已登记 ic/CLAUDE.md §2 图表规范。关联 [[latex-unicode-math]]。
