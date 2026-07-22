---
type: spec
aliases:
  - 数字IC 项目 CLAUDE 指南
  - ASIC 执行规范
tags:
  - asic
  - claude
  - policy
source_spec: "Local project instructions"
---

# 数字IC 项目 CLAUDE.md

## 硬性规则

### 1. 术语规范

- 数字IC术语首现必须标注 "中文（English Full Name, ABBR）"，如 "寄存器传输级（Register Transfer Level, RTL）"
- 此后可用英文缩写或中文简称
- 禁止口语化标题（如 "搞清楚流水线" → 应为 "流水线（Pipelining）原理"）

### 2. 图表规范

- 波形图/时序图 → Wavedrom（`.json` → `.html` → `.svg`）
- 电路图/架构图/模块框图 → ≤50 节点 Mermaid，>50 节点 PlantUML
- 所有图表必须输出 SVG 作为主格式，PNG 为可选
- 图表文件放在对应概念的 `assets/` 子目录

### 3. 代码规范

- HDL 代码必须标注语言类型：````verilog` 或 ````systemverilog`
- 脚本标注：````tcl` / ````python` / ````shell`
- 代码块上方必须有简短注释说明用途

### 4. Wikilink 规范

- 概念间引用使用 Obsidian wikilink：`[[path/to/file|显示文本]]`
- 与 3gpp 知识库交叉引用使用标签 `#ic-bridge`
- 跨领域概念优先链接到 `cross-domain/` 下的对应文件

### 5. 项目背景

本项目是数字IC全栈知识库，覆盖六大领域：

- `rtl-design/` — RTL 设计与编码（Verilog/SystemVerilog，FSM，CDC，流水线）
- `verification/` — 功能验证（UVM，SVA，覆盖率，形式验证）
- `architecture/` — 计算机体系结构（流水线，乱序执行，缓存，总线，SoC）
- `asic-flow/` — ASIC 实现流程（综合，STA，DFT，布局布线，Signoff）
- `cross-domain/` — 跨领域概念（时序收敛，低功耗，复位策略，CDC）
- `concepts/` — 数字IC基础（CMOS，数制，亚稳态，半导体基础）

### 6. 内容质量标准

- 每个概念文件 100-400 行
- 原理部分至少 2-3 段实质性内容，不能只有一句话
- "关键要点" 至少 5 条
- "与其他概念的关系" 至少 2 个 wikilink
- 禁止空壳文件（仅标题 + 一句话 + 无实质内容的占位符）
