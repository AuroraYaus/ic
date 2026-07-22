---
type: concept
aliases:
  - Logic Synthesis
  - 逻辑综合
tags:
  - asic
  - asic-flow
  - synthesis
  - front-end
source_spec: "Synopsys Design Compiler User Guide, Cadence Genus User Guide, Weste & Harris CMOS VLSI Design Ch.13"
---

# 逻辑综合（Logic Synthesis）

逻辑综合（Logic Synthesis）是 ASIC 实现流程的第一个关键阶段，其任务是将寄存器传输级（Register Transfer Level, RTL）的硬件描述代码自动转换为由标准单元库中的门级电路组成的网表（Gate-Level Netlist）。综合过程不是简单的"翻译"，而是在满足时序、面积和功耗约束的前提下，进行大量优化决策的智能搜索过程。

## 原理

### 三阶段综合流程

现代逻辑综合工具（如 Synopsys Design Compiler、Cadence Genus）的执行过程分为三个主要阶段。第一阶段是 **RTL 精化（RTL Elaboration）**：综合工具解析 Verilog/SystemVerilog 代码，推断出寄存器、组合逻辑、状态机和存储器等高层结构，生成与工艺无关的通用技术网表（Generic Technology Network, GTECH 或 Generic Netlist）。精化阶段会进行基本的算术优化（如乘法器重构、常数传播）和冗余逻辑消除。

第二阶段是 **工艺无关优化（Technology-Independent Optimization）**：工具在布尔代数层面优化逻辑结构。主要手段包括公共子表达式提取（Common Sub-expression Elimination）、逻辑重构（Logic Restructuring）——利用布尔函数的等价变换减少逻辑级数。例如 `f = ab + ac` 可因式分解为 `f = a(b + c)`，将两级逻辑减少为一级与门加一级或门。此外还有资源共享（Resource Sharing）：互斥操作可以共用同一个运算单元以节省面积。这一阶段的优化不涉及具体工艺库信息，只关注逻辑表达式的简化。

第三阶段是 **技术映射（Technology Mapping）**：工具将优化后的工艺无关网表映射到目标标准单元库的具体门电路上。映射过程使用动态规划或 DAG（Directed Acyclic Graph）覆盖算法，将逻辑树分解为子图并与库中的门单元进行匹配。关键技术包括：分解（Decomposition）——将复杂逻辑函数分解为库中已有门的组合；扇出优化——插入缓冲器以满足扇出限制；驱动强度选择——根据负载电容选择适当的驱动能力。物理感知综合（Physical-Aware Synthesis）进一步引入了布局信息的反馈，在映射阶段就考虑互连线延迟和拥塞，避免了传统"综合→布局"迭代的反复。

### SDC 约束体系

综合的质量高度依赖于设计约束（Synopsys Design Constraints, SDC）文件的完整性和准确性。核心约束包括：

- **时钟定义（`create_clock`）**：指定时钟名称、周期（-period）、波形（-waveform）和时钟源端口。时钟是整个时序约束体系的根基，所有时序路径都围绕时钟定义展开。
- **输入延迟（`set_input_delay`）**：定义外部信号到达输入端口的延迟，代表了芯片外部的时序预算。输入延迟的值来自系统级时序分析，通常由板级 PCB 走线延迟加上上游芯片的时钟到输出（Clock-to-Output）时间组成。
- **输出延迟（`set_output_delay`）**：定义输出信号在芯片外部需要的建立时间，代表了接收端对外部信号的时序要求。
- **时钟不确定性（`set_clock_uncertainty`）**：为建立/保持时间检查增加余量，涵盖时钟抖动（Jitter）、偏斜（Skew）和额外的设计余量。
- **输入/输出驱动和负载**：`set_driving_cell` 和 `set_load` 指定端口的外部驱动能力和负载电容，使工具能计算准确的端口延迟。

### 优化策略

综合工具的优化引擎可以根据设计目标选择不同的侧重点。**时序驱动优化（Timing-Driven Optimization）** 以建立时间违例（Setup Violation）为第一优先级：工具计算每条路径的到达时间（Arrival Time）与要求时间（Required Time），在违例路径上优先进行逻辑重构、门尺寸调整或插入 buffer。**面积驱动优化（Area-Driven Optimization）** 在时序已满足的前提下，通过门尺寸下调和逻辑合并来最小化总面积。

线负载模型（Wire Load Model, WLM）在物理信息缺失的早期阶段估算互连线延迟。WLM 基于面积统计给出线长与扇出的经验关系，但在深亚微米工艺中，互连线延迟已经超过门延迟，传统 WLM 的误差变得不可接受。为此，现代流程使用物理综合（Physical Synthesis）和拓扑模式（Topographical Mode），在综合阶段引入粗略的布局信息，大幅提升时序估算的准确性。

## 关键要点

- 综合三阶段：RTL 精化（推断高层结构）→ 工艺无关优化（布尔级逻辑简化）→ 技术映射（映射到标准单元库的门级网表），三个阶段缺一不可
- `create_clock` 和 `create_generated_clock` 是时序约束的根基，时钟定义错误会导致整个综合结果无效，是 ASIC 流程中的"第一因"
- 时序驱动优化（Timing-Driven）以建立时间违例修复为首要目标，面积驱动优化（Area-Driven）在时序闭合后再压缩面积，两者是"先达标再节流"的逻辑
- 物理感知综合（Physical-Aware/Physical Synthesis）将布局信息反馈到综合阶段，大幅减少了传统流程中综合与布局之间的时序迭代
- 约束完整性检查（`check_timing`）应在综合前强制执行——发现未约束的路径、不合理的多周期约束或缺失的时钟定义
- 综合输出包括门级网表（Verilog）、SDC 文件（可传递到下游工具）、延迟信息（SDF 或工具数据库）和设计约束报告，这些输出是后续 STA 和 P&R 的输入
- 门控时钟（Clock Gating）的插入通常由综合工具自动完成（通过 `set_clock_gating_style` 指令），能节省 20%-40% 的动态功耗
- 综合中的 don't_touch 属性保护关键路径和手工设计的电路不被工具意外修改，必须谨慎使用——过度保护会限制优化空间

## 与其他概念的关系

- [[asic-flow/concepts/static-timing-analysis|静态时序分析（STA）]] — 综合后的网表需要通过 STA 验证时序，SDC 约束在综合和 STA 中共享
- [[asic-flow/concepts/clock-tree|时钟树综合（CTS）]] — 综合阶段假定时钟理想抵达，CTS 阶段才引入真实的时钟延迟和偏斜
- [[asic-flow/concepts/place-and-route|布局布线（P&R）]] — 综合输出的门级网表是 P&R 的直接输入，物理综合的目标就是减少综合与 P&R 之间的时序鸿沟
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — 门控时钟是综合阶段的核心低功耗技术，门控使能信号的生成逻辑直接影响功耗效率
- [[rtl-design/coding-for-synthesis|综合友好编码]] — RTL 编码风格直接决定综合结果的质量，推断锁存器、多驱动和组合环路是三大致命问题
