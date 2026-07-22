---
type: index
aliases:
  - Digital IC Hub_数字IC知识库
  - ASIC Knowledge Base
  - 数字IC入口
tags:
  - asic
  - index
  - moc
source_spec: "Local vault index"
---
# Digital IC — 数字IC知识库

数字集成电路（Digital Integrated Circuit）设计全栈知识库，覆盖从 RTL 编码到 GDSII 签核的完整 ASIC 设计流程。

## 领域入口

| 领域 | 入口 | 核心主题 |
|:---|:---|:---|
| RTL 设计 | [[rtl-design/RTL Design_RTL设计|RTL 设计 MOC]] | Verilog, SystemVerilog, FSM, CDC, 流水线 |
| 验证 | [[verification/Verification_功能验证|验证 MOC]] | UVM, SVA, 覆盖率, 形式验证 |
| 体系结构 | [[architecture/Architecture_体系结构|体系结构 MOC]] | 流水线, 乱序执行, 缓存, 总线, SoC |
| ASIC 流程 | [[asic-flow/ASIC Flow_ASIC流程|ASIC 流程 MOC]] | 综合, STA, DFT, 布局布线, Signoff |

## 跨领域概念

- [[cross-domain/Cross-Domain_跨领域|跨领域 MOC]] — 贯穿全流程的系统性工程问题总览
- [[cross-domain/concepts/Timing Closure_时序收敛|时序收敛（Timing Closure）]] — 贯穿 RTL到Signoff 的核心闭环
- [[cross-domain/concepts/Low Power Design_低功耗设计|低功耗设计（Low Power Design）]] — 从架构到物理实现的功耗优化
- [[cross-domain/concepts/Clock Domain Crossing_跨时钟域设计|跨时钟域（Clock Domain Crossing）]] — 多时钟 SoC 的同步策略
- [[cross-domain/concepts/Reset Methodology_复位策略|复位策略（Reset Methodology）]] — 复位方案的选择与实现

## 基础概念

- [[concepts/CMOS Fundamentals_CMOS基础|CMOS 基础]] — 数字IC的物理工艺基础
- [[concepts/Number Systems_数制|数字的数制表示]] — 二进制、补码、定点数、浮点数
- [[concepts/Metastability_亚稳态|亚稳态（Metastability）]] — 跨时钟域问题的物理根源
- [[concepts/Semiconductor Basics_半导体基础|半导体基础]] — PN 结、MOSFET、PVT 变异

## 关联知识库

- **3GPP LTE/NR 译码链路**（独立 Obsidian vault: `~/AGENT/obsidian/3gpp/`） — 通信基带协议与算法

## 项目规范

- [[CLAUDE|CLAUDE.md]] — 项目规则、术语规范与内容标准
