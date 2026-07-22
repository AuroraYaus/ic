---
type: concept
aliases:
  - 时序逻辑
  - Sequential Logic
  - D触发器
  - D Flip-Flop
  - 建立时间
  - 保持时间
tags:
  - asic
  - rtl
  - sequential
  - timing
  - flip-flop
source_spec: "Wakerly, Digital Design; Weste & Harris, CMOS VLSI Design; Rabey, Digital Integrated Circuits"
---

# 时序逻辑（Sequential Logic）

时序逻辑是数字电路的另一半核心——与组合逻辑输出仅取决于当前输入不同，时序逻辑的输出依赖于当前输入**和**历史状态，即电路具有记忆能力。同步时序逻辑以边沿触发的 D 触发器（D Flip-Flop, D-FF）为基本存储单元，在时钟节拍的控制下统一更新状态，构成了现代数字系统的同步设计范式（Synchronous Design Methodology）。在同步时序电路中，所有状态寄存器由同一个（或时钟树平衡的多个）时钟驱动，任意两个寄存器之间的数据通路是纯组合逻辑，时序收敛（Timing Closure）即在预定的时钟周期内确保所有路径的建立/保持时间约束得到满足。这一范式将时序验证问题从"任意状态在任意时刻变化"的模拟电路难题，简化为"相邻寄存器间组合路径延迟小于时钟周期"的静态时序分析（Static Timing Analysis, STA）问题——STA 是 ASIC 后端流程的数学基石。

## 原理

### D 触发器基础与建立/保持时间

D 触发器是同步时序系统的原子存储单元，在时钟有效沿（上升沿或下降沿）将输入 D 的值捕获并保持输出 Q 直到下一时钟沿，即 Q[n+1] = D[n]。D-FF 的晶体管级实现通常使用主从（Master-Slave）结构或脉冲锁存器（Pulsed Latch）结构。主从 D-FF 由两个电平敏感锁存器串联组成：主级在时钟低电平时透明（Transparent），从级在时钟高电平时透明；两级时钟反相连接，保证任何时刻最多只有一个锁存器透明，从而在有效时钟边沿前后实现边沿触发的采样行为。

**建立时间（Setup Time, t_su）** 是 D 端数据必须在时钟有效沿**之前**保持稳定的最短时间——主级锁存器需要在时钟沿到达前完成数据捕获，若数据变化太靠近时钟沿，主级的正反馈环路来不及稳定到正确值，在时钟脉冲关闭后可能恢复（析出）到错误状态（亚稳态 Metastability 的前身）。**保持时间（Hold Time, t_h）** 是 D 端数据必须在时钟有效沿**之后**继续保持稳定的最短时间——这是为了防止时钟沿到来时 D 到 Q 路径打开、新数据直通输出导致的透明穿通（Race-Through）效应。建立时间和保持时间是标准单元库中每个触发器的最重要时序参数，由晶体管的驱动强度、节点电容和工艺条件决定。建立时间违反（Setup Violation）可以通过降低时钟频率来修复（因为建立时间约束为 t_clk >= t_su + t_cq + t_comb），但保持时间违反（Hold Violation）与时钟频率无关——保持时间约束为 t_cq_min + t_comb_min >= t_hold，只能通过增加组合逻辑延迟（插入 Buffer Delay）或调整时钟偏斜来修复。

### 同步复位与异步复位

复位信号将触发器强制恢复到已知状态，是上电初始化、故障恢复和 DFT 扫描测试的基础。RTL 设计中复位策略的核心选择是同步复位（Synchronous Reset）还是异步复位（Asynchronous Reset）。

**同步复位**：复位信号在时钟有效沿被采样后才生效——`always_ff @(posedge clk) if (!rst_n) q <= 0; else q <= d;`。优点：复位释放时序与时钟同步，无恢复/移除（Recovery/Removal）时序问题；复位信号作为普通数据路径的输入，综合工具可以对其进行时序优化；STA 分析单纯。缺点：复位需要时钟有效才能生效，门控时钟关断时无法复位；复位信号经过组合逻辑可能增加数据路径延迟；需要额外的复位脉冲展宽电路确保复位被采样。

**异步复位**：复位信号异步生效（直接清零 D-FF 内容），与时钟无关——`always_ff @(posedge clk or negedge rst_n) if (!rst_n) q <= 0; else q <= d;`。优点：不需要时钟即可复位，适用于门控时钟关断场景；复位路径延迟短（直连触发器异步清零端）；DFT 友好。缺点：复位**释放**（Deassertion）必须与时钟沿同步，否则产生恢复时间违反（Recovery Time Violation）和移除时间违反（Removal Time Violation）——这等价于异步复位信号对时钟的建立/保持约束；复位信号上的毛刺会错误触发复位（需在复位产生电路上加毛刺过滤）；异步复位网络上的延时不均导致同一时钟域的不同寄存器在不同时钟周期退出复位，产生功能错误。

现代 ASIC 实践中，推荐采用**异步复位 + 同步释放**的混合策略：复位网络遍布芯片异步清零所有寄存器；复位释放由一个两级同步器（Reset Synchronizer）在目标时钟域内同步到时钟沿后统一释放，确保恢复/移除时间约束得到满足，同时避免不同寄存器的复位释放偏移。

### 时钟使能与时钟门控

**时钟使能（Clock Enable）** 是多周期路径和低功耗设计的基本机制。在 RTL 中通过数据路径上的 MUX 反馈实现：`always_ff @(posedge clk) if (clk_en) q <= d;`——当时钟使能为低时，寄存器保持当前值（q <= q）。这等效于一个数据反馈选择器，综合工具将其优化为专用的时钟使能引脚（D-FF 通常内置 CE 输入）。

**时钟门控（Clock Gating）** 则更进一步：当时钟使能无效时，直接关断寄存器的时钟信号，不仅阻止状态更新，还消除寄存器时钟树上的无效功耗（动态功耗的核心来源）。粗粒度的模块级时钟门控（Block-Level Clock Gating）由综合工具自动插入——将一组共享使能信号的寄存器的时钟信号与或来自一个**集成时钟门控单元（Integrated Clock Gating Cell, ICG）**。ICG 内部使用电平敏感锁存器（Low-Phase Latch）来确保时钟门控使能信号只在时钟低电平期间变化，防止时钟脉冲上产生毛刺——这是时钟门控正确性的关键时序条件（Setup of Enable = half cycle）。

### 时序路径与时序收敛

从时序分析的视角，同步电路中的每条数据路径都可以描述为：
- **出发点**（Launch）：源寄存器在时钟有效沿 (t=0) 发出数据
- **组合逻辑路径**：数据经过 t_cq (Clock-to-Q) + t_comb (组合逻辑传播延迟) 的传播
- **目的点**（Capture）：目标寄存器在下一个时钟沿 (t=T_clk) 采样数据
- **建立时间约束**：t_cq + t_comb + t_su < T_clk —— 数据必须在捕获沿之前到达且稳定
- **保持时间约束**：t_cq_min + t_comb_min > t_hold —— 数据不得在捕获沿之后过早变化

时序收敛（Timing Closure）即确保设计中所有时序路径满足上述两个约束。STA 工具将设计中的所有路径分为四类：寄存器到寄存器（Reg2Reg）、输入端口到寄存器（Input2Reg）、寄存器到输出端口（Reg2Output）、输入端口到输出端口（Input2Output），分别施加相应的时序约束后，逐条路径计算建立/保持 slack。建立时间为负（Negative Slack）时，标准修复手段包括逻辑优化（面积换速度 Structural Transformation）、寄存器重时序（Retiming）、流水线插入（Pipelining）；保持时间为负时，通过在快速路径上插入延迟单元（Buffer/Delay Cell）修复。

## 关键要点

- 建立时间违反与时钟周期相关，降低频率可修复；保持时间违反与频率无关，只能通过增加组合延迟或调整时钟偏斜修复
- 同步复设 STA 分析简单但需时钟有效才能复位；异步复位不需时钟但释放必须同步，否则产生 Recovery/Removal 违例
- 异步复位 + 同步释放（Reset Synchronizer）是工业界广泛采用的复位策略，兼顾异步清零便利性与同步释放安全性
- 时钟门控通过 ICG 在使能无效时关断寄存器时钟，可降低 20%-50% 的动态功耗，是低功耗设计的必选手段
- ICG 内部的低相锁存器（Low-Phase Latch）保证使能信号仅在时钟低电平时变化，防止门控时钟上的毛刺
- D-FF 的保持时间来源于主级锁存器的透明穿通窗口，在先进工艺中（<7nm）保持时间违反已成为时序收敛的主要矛盾
- 多周期路径（Multicycle Path）是非关键路径的常用时序例外（Timing Exception），通过放宽目标寄存器采样沿来释放综合/布局布线压力
- 假路径（False Path）是功能上不可能被激活的路径（如异步复位网络），需通过 SDC 约束明确告知 STA 工具不可花费优化资源
- 时序路径中，出发沿（Launch Edge）和捕获沿（Capture Edge）可以不是相邻边沿——半周期路径（Half-Cycle Path）中两个沿相差半个周期，常用于锁存器基准设计
- 寄存器复制（Register Duplication/Cloning）将一个高扇出寄存器的负载拆分到多个并行寄存器，降低每个寄存器的输出延迟，是 Reg2Output 路径的高效优化手段

## 与其他概念的关系

- [[concepts/cmos-fundamentals|CMOS 基础]] — D 触发器的晶体管级主从结构实现、时钟到输出的传输门链、亚阈值漏电对保持时间的影响
- [[rtl-design/concepts/combinational-logic|组合逻辑]] — 时序逻辑 = 组合逻辑 + 寄存器；锁存器推断与有意锁存器设计的区别
- [[rtl-design/concepts/fsm-design|状态机设计]] — 时序逻辑是状态机实现的基础，always_ff 中的状态寄存器和 always_comb 中的次态逻辑
- [[rtl-design/concepts/cdc-cross-domain|跨时钟域（CDC）]] — D-FF 是同步器的基本单元，亚稳态和 MTBF 的管理方法
