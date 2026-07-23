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
# 数字IC知识库

数字集成电路（Digital Integrated Circuit）设计全栈知识库，覆盖从 RTL 编码到 GDSII 签核的完整 ASIC 设计流程。

## 领域入口

| 领域 | 入口 | 核心主题 |
|:---|:---|:---|
| RTL 设计 | [[rtl-design/RTL设计|RTL 设计 MOC]] | Verilog, SystemVerilog, FSM, CDC, 流水线 |
| 验证 | [[verification/功能验证|验证 MOC]] | UVM, SVA, 覆盖率, 形式验证 |
| 体系结构 | [[architecture/体系结构|体系结构 MOC]] | 流水线, 乱序执行, 缓存, 总线, SoC |
| ASIC 流程 | [[asic-flow/ASIC流程|ASIC 流程 MOC]] | 综合, STA, DFT, 布局布线, Signoff |

## 跨领域概念

- [[cross-domain/跨领域|跨领域 MOC]] — 贯穿全流程的系统性工程问题总览
- [[cross-domain/concepts/时序收敛|时序收敛（Timing Closure）]] — 贯穿 RTL到Signoff 的核心闭环
- [[cross-domain/concepts/低功耗设计|低功耗设计（Low Power Design）]] — 从架构到物理实现的功耗优化
- [[cross-domain/concepts/跨时钟域设计|跨时钟域（Clock Domain Crossing）]] — 多时钟 SoC 的同步策略
- [[cross-domain/concepts/复位策略|复位策略（Reset Methodology）]] — 复位方案的选择与实现

## 基础概念

- [[concepts/CMOS基础|CMOS 基础]] — 数字IC的物理工艺基础
- [[concepts/数制|数字的数制表示]] — 二进制、补码、定点数、浮点数
- [[concepts/亚稳态|亚稳态（Metastability）]] — 跨时钟域问题的物理根源
- [[concepts/半导体基础|半导体基础]] — PN 结、MOSFET、PVT 变异

## 关联知识库

- **3GPP LTE/NR 译码链路**（独立 Obsidian vault: `~/AGENT/obsidian/3gpp/`） — 通信基带协议与算法

## 项目规范

- [[CLAUDE|CLAUDE.md]] — 项目规则、术语规范与内容标准

## 全库高频查询（易忘知识点总排名）

按查询次数降序，跨领域汇总所有 MOC 高频查询条目。

| 总排名 | 领域 | 概念 | 查询次数 | 最后查询 |
|:---|:---|:---|:---|:---|
| 1 | ASIC 流程 | [[asic-flow/concepts/静态时序分析\|STA / Critical Path / Skew & Jitter / Multi-Cycle / False Path / Fmax / OCV]] | 12 | 2026-07-23 |
| 2 | 体系结构 | [[architecture/concepts/片上总线\|AHB / APB / AXI / QoS / Interconnect]] | 8 | 2026-07-23 |
| 3 | RTL 设计 | [[rtl-design/concepts/组合逻辑\|毛刺 / 异或门 / 竞争冒险 / 扇入扇出]] | 7 | 2026-07-23 |
| 4 | RTL 设计 | [[rtl-design/concepts/时序逻辑\|锁存器与触发器 / 同步异步电路 / 分频器]] | 5 | 2026-07-23 |
| 5 | 跨领域 | [[cross-domain/concepts/低功耗设计\|时钟门控ICG / 操作数隔离 / 低功耗技术全景]] | 4 | 2026-07-23 |
| 6 | 体系结构 | [[architecture/concepts/存储层次\|Cache 组织 / MMU / 虚拟内存]] | 4 | 2026-07-23 |
| 7 | 跨领域 | [[concepts/亚稳态\|亚稳态 / MTBF / 准稳态]] | 3 | 2026-07-23 |
| 8 | RTL 设计 | [[rtl-design/concepts/SystemVerilog\|阻塞/非阻塞 / task-function / interface / 综合子集]] | 3 | 2026-07-23 |
| 9 | RTL 设计 | [[rtl-design/concepts/有限状态机\|一段/两段/三段式 / 状态编码 / 安全状态机]] | 3 | 2026-07-23 |
| 10 | RTL 设计 | [[rtl-design/concepts/跨时钟域设计\|异步FIFO / 多比特CDC / 格雷码 / 握手协议]] | 3 | 2026-07-23 |
| 11 | ASIC 流程 | [[asic-flow/concepts/逻辑综合\|面积速度权衡 / 资源共享 / Retiming]] | 3 | 2026-07-23 |
| 12 | 体系结构 | [[architecture/concepts/外设总线协议\|DDR / SPI / I2C / PCIe]] | 3 | 2026-07-23 |
| 13 | 跨领域 | [[cross-domain/concepts/跨时钟域设计\|时钟域分类 / CDC验证 / 同步器策略]] | 2 | 2026-07-23 |
| 14 | RTL 设计 | [[rtl-design/concepts/Verilog-HDL\|阻塞非阻塞赋值 / Scheduling队列 / 同步FIFO]] | 2 | 2026-07-23 |
| 15 | RTL 设计 | [[rtl-design/concepts/流水线设计\|加速比 / 效率 / 超标量 / 乱序执行]] | 2 | 2026-07-23 |
| 16 | ASIC 流程 | [[asic-flow/concepts/布局布线\|Floorplan / Placement / CTS / Routing]] | 2 | 2026-07-23 |
| 17 | 验证 | [[verification/concepts/SVA断言\|cover/assume/assert/property/sequence 区别]] | 2 | 2026-07-23 |
| 18 | 体系结构 | [[architecture/concepts/指令集架构基础\|冯·诺依曼 / 哈佛 / RISC / CISC]] | 2 | 2026-07-23 |
| 19 | 体系结构 | [[architecture/concepts/乱序执行\|乱序执行 / 超标量]] | 2 | 2026-07-23 |
| 20 | 体系结构 | [[architecture/concepts/DMA与中断\|DMA / 中断]] | 2 | 2026-07-23 |

> 完整排名详见各领域 MOC 的"高频查询"表。计数仅含通过 Q&A Pipeline 统计的查询，非全量访问统计。
