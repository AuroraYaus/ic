---
type: moc
aliases:
  - RTL Design MOC_RTL设计总览
  - RTL Design Map of Content
tags:
  - asic
  - rtl
  - moc
source_spec: "IEEE 1364, IEEE 1800, Weste & Harris CMOS VLSI Design"
queries: 1
---
# RTL 设计总览

寄存器传输级（Register Transfer Level, RTL）设计是数字集成电路开发流程的核心环节，它用硬件描述语言（Hardware Description Language, HDL）描述设计在寄存器之间的数据传输和逻辑运算。RTL 代码通过逻辑综合（Synthesis）工具转换为门级网表（Gate-Level Netlist），是连接架构设计与物理实现的桥梁。

本 MOC 汇总 RTL 设计领域的核心概念，涵盖 HDL 语言、组合/时序逻辑基础、有限状态机、流水线、跨时钟域（CDC）、算术电路和编码风格等主题。

## 核心概念索引

### 硬件描述语言

- [[rtl-design/concepts/Verilog-HDL|Verilog HDL]] — IEEE 1364 标准，wire/reg 数据类型，阻塞/非阻塞赋值，可综合子集
- [[rtl-design/concepts/SystemVerilog|SystemVerilog（SV）]] — IEEE 1800 标准，Verilog 的超集，logic/interface/enum 等现代抽象

### 逻辑设计基础

- [[rtl-design/concepts/组合逻辑|组合逻辑（Combinational Logic）]] — 真值表→门级映射，MUX 实现，锁存器推断，冒险与毛刺
- [[rtl-design/concepts/时序逻辑|时序逻辑（Sequential Logic）]] — D 触发器，建立/保持时间，同步/异步复位，门控时钟
- [[rtl-design/concepts/有限状态机|有限状态机设计（FSM Design）]] — Moore vs Mealy，三段式编码，状态编码权衡，FSM+Datapath 架构

### 设计方法论

- [[rtl-design/concepts/流水线设计|流水线设计（Pipeline Design）]] — 吞吐率 vs 延迟，停顿/冲刷协议，Valid-Ready 握手机制
- [[rtl-design/concepts/跨时钟域设计|跨时钟域（Clock Domain Crossing, CDC）]] — 亚稳态，2-FF 同步器，格雷码 FIFO，握手同步
- [[rtl-design/concepts/算术电路|算术电路（Arithmetic Circuits）]] — 加法器（RCA/CLA/CSA），Booth 乘法，Wallace 树，移位器
- [[rtl-design/concepts/编码风格|RTL 编码风格（RTL Coding Style）]] — 命名规范，参数化设计，可综合约束，CDC 最佳实践
- [[rtl-design/concepts/FIFO设计|FIFO 设计（FIFO Design）]] — 同步/异步 FIFO，空满判断，格雷码指针，FWFT 模式，Almost Full/Empty

## 相关领域

- [[verification/功能验证|功能验证（Verification）]] — UVM、SVA、覆盖率驱动的验证方法论
- [[asic-flow/ASIC流程|ASIC 实现流程（ASIC Flow）]] — 综合、STA、DFT、布局布线、Signoff
- [[cross-domain/concepts/跨时钟域设计|跨领域 — 时钟域交叉（CDC）]] — 跨领域的 CDC 理论与实践

## 推荐阅读顺序

对于刚接触 RTL 设计的学习者，建议按以下顺序阅读：

1. 先建立硬件描述语言的认知：[[rtl-design/concepts/Verilog-HDL|Verilog HDL]] → [[rtl-design/concepts/SystemVerilog|SystemVerilog]]
2. 理解数字逻辑的两大基石：[[rtl-design/concepts/组合逻辑|组合逻辑]] → [[rtl-design/concepts/时序逻辑|时序逻辑]]
3. 掌握核心设计方法论：[[rtl-design/concepts/有限状态机|FSM 设计]] → [[rtl-design/concepts/流水线设计|流水线设计]] → [[rtl-design/concepts/算术电路|算术电路]]
4. 深入工程实践：[[rtl-design/concepts/跨时钟域设计|CDC]] → [[rtl-design/concepts/编码风格|编码风格]]

## 高频查询（易忘知识点排名）

| 排名 | 概念 | 查询次数 | 最后查询 |
|:---|:---|:---|:---|
| 1 | [[rtl-design/concepts/组合逻辑|组合逻辑（毛刺、异或门、竞争冒险、扇入扇出）]] | 7 | 2026-07-23 |
| 2 | [[rtl-design/concepts/时序逻辑|时序逻辑（锁存器与触发器、同步异步电路、分频器）]] | 5 | 2026-07-23 |
| 3 | [[rtl-design/concepts/SystemVerilog|SystemVerilog（阻塞/非阻塞/task-function/interface/casex/调度队列/综合子集）]] | 3 | 2026-07-23 |
| 4 | [[rtl-design/concepts/有限状态机|有限状态机（FSM / 一段式两段式三段式 / 状态编码 / 安全状态机）]] | 3 | 2026-07-23 |
| 5 | [[rtl-design/concepts/跨时钟域设计|CDC 异步FIFO / 多比特 / 格雷码 / 握手协议]] | 3 | 2026-07-23 |
| 6 | [[rtl-design/concepts/Verilog-HDL|Verilog HDL（阻塞非阻塞赋值/scheduling队列/NBA区域/同步FIFO）]] | 2 | 2026-07-23 |
| 7 | [[rtl-design/concepts/流水线设计|流水线设计（加速比 / 效率 / 超标量 / 乱序执行）]] | 2 | 2026-07-23 |
| 8 | [[rtl-design/concepts/算术电路|算术电路（半加器/全加器/RCA/CLA/计数器/移位寄存器）]] | 1 | 2026-07-23 |
| 9 | [[rtl-design/concepts/FIFO设计|FIFO 设计（同步FIFO/异步FIFO/Gray码/FWFT/Almost Full/Empty）]] | 1 | 2026-07-23 |
