---
type: moc
aliases:
  - Architecture MOC_体系结构总览
  - Computer Architecture Map of Content
tags:
  - asic
  - architecture
  - moc
source_spec: "Hennessy & Patterson, Computer Architecture: A Quantitative Approach; Digital Design and Computer Architecture (Harris & Harris)"
---

# 计算机体系结构（Computer Architecture）— 总览

计算机体系结构是数字IC设计中承上启下的关键层次——它向下驱动微架构和RTL实现，向上支撑指令集架构（Instruction Set Architecture, ISA）和软件生态。体系结构决策（流水线深度、缓存层次、总线拓扑、乱序程度）直接决定了芯片的性能（Performance）、功耗（Power）和面积（Area, PPA）三大指标。

本 MOC 汇总计算机体系结构领域的核心概念，涵盖微架构设计、内存系统、互连总线和 SoC 集成四大板块。

## 核心概念索引

### 微架构设计

- [[architecture/concepts/pipelining|流水线（Pipelining）]] — 经典 RISC 五级流水线、数据/控制/结构冲突、转发与停顿
- [[architecture/concepts/out-of-order|乱序执行（Out-of-Order Execution）]] — Tomasulo 算法、寄存器重命名、重排序缓冲（ROB）、推测执行
- [[architecture/concepts/branch-prediction|分支预测（Branch Prediction）]] — 双峰预测器、全局历史/GHARE、锦标赛预测器、TAGE、BTB/RAS

### 内存系统

- [[architecture/concepts/memory-hierarchy|存储层次（Memory Hierarchy）]] — 局部性原理、缓存组织、替换策略、写策略、TLB 与虚拟内存
- [[architecture/concepts/cache-coherence|缓存一致性（Cache Coherence）]] — MSI/MESI/MOESI 协议、监听式与目录式一致性、内存一致性模型

### 互连总线

- [[architecture/concepts/on-chip-bus|片上总线协议（On-Chip Bus Protocols）]] — AXI4/AXI5 通道模型、AHB vs AXI、CHI 一致性互连、片上网络（NoC）

### SoC 集成

- [[architecture/concepts/soc-architecture|SoC 体系结构（SoC Architecture）]] — 异构多核、互连架构、功耗/时钟域、Die-to-Die 互连、Chiplet 与安全

## 相关领域

- [[rtl-design/rtl-design_MOC|RTL 设计]] — 体系结构的设计决策最终由 RTL 代码实现，微架构规范直接映射到 RTL 模块
- [[asic-flow/asic-flow_MOC|ASIC 实现流程]] — 时序收敛、物理设计、功耗分析等后端流程验证体系结构的 PPA 目标
- [[verification/verification_MOC|功能验证]] — 复杂微架构特性（乱序、一致性、虚存）需要系统级的验证策略

## 推荐阅读顺序

1. 先建立流水线基础：[[architecture/concepts/pipelining|流水线]] — 这是所有现代处理器的基石
2. 理解存储系统：[[architecture/concepts/memory-hierarchy|存储层次]] → [[architecture/concepts/cache-coherence|缓存一致性]]
3. 深入高级微架构：[[architecture/concepts/out-of-order|乱序执行]] → [[architecture/concepts/branch-prediction|分支预测]]
4. 扩展到系统和互连：[[architecture/concepts/on-chip-bus|片上总线协议]] → [[architecture/concepts/soc-architecture|SoC 体系结构]]
