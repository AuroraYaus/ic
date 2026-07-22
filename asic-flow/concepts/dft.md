---
type: concept
aliases:
  - DFT
  - Design for Testability
  - 可测试性设计
tags:
  - asic
  - asic-flow
  - dft
  - test
  - front-end
source_spec: "Bushnell & Agrawal Essentials of Electronic Testing, IEEE 1149.1 JTAG Standard, IEEE 1687 IJTAG Standard, Mentor/Synopsys DFT User Guides"
---

# 可测试性设计（Design for Testability）

可测试性设计（Design for Testability, DFT）是在芯片设计阶段主动嵌入测试结构的工程方法，其核心目标是在芯片制造完成后能够高效地检测出制造缺陷（Manufacturing Defect）。不可测的芯片是不可靠的——没有 DFT 结构的芯片依赖于外部 I/O 直接驱动内部节点做功能测试，这在现代深亚微米 SoC（系统级芯片）中包含数亿甚至数百亿晶体管的情况下已完全不可行。DFT 通过扫描链、内建自测试（BIST）和边界扫描等手段，系统性地解决了大规模数字 IC 的可控性（Controllability）和可观测性（Observability）问题。

## 原理

### 扫描链架构与插入流程

扫描链（Scan Chain）是 DFT 的核心技术，其基本思想是将设计中所有（或大部分）时序单元——即触发器（Flip-Flop, FF）——替换为可扫描的等效单元，并通过一条或多条串行链路将它们级联起来，使内部状态变为可控制和可观察。标准的扫描触发器是 MUX-DFF（多路选择器型 D 触发器）：在正常功能模式下（scan_enable = 0），数据输入端 D 连接到前一组合逻辑的输出；在扫描模式下（scan_enable = 1），扫描输入端 SI（Scan-In）被选中，来自前一级扫描触发器的 Q 输出串行送入。

扫描插入流程在综合之后进行，主要步骤包括：扫描替换（Scan Replacement）——将设计中的所有非扫描触发器替换为对应的扫描触发器（SDFF），通常由 DFT 工具（如 Synopsys DFT Compiler、Mentor Tessent）自动完成；扫描链连接（Scan Chain Stitching）——将扫描触发器按链串行连接，链的长度需要在测试时间（链越短越并行，测试时间越短）和测试引脚数量（链越多需要的 SI/SO 引脚越多）之间平衡；扫描链验证（Scan Chain Validation）——确认所有扫描链的连通性和移位功能正确，包括 DRC 检查（如复位信号是否与扫描模式冲突、三态总线是否有争用等）。

### ATPG 算法

自动测试向量生成（Automatic Test Pattern Generation, ATPG）的任务是为芯片的制造缺陷生成最小但最有效的测试向量集。ATPG 算法经过数十年的演进：

- D 算法（D-Algorithm, Roth 1966）：最早的系统化 ATPG 方法。引入复合逻辑值 D（表示正常电路中为 1、故障电路中为 0 的信号）和 D'（表示正常为 0 故障为 1），通过 D 驱动（D-Drive）将故障效应传播到可观测输出，再通过一致性操作（Consistency/J-Frontier）回推到输入端口确定需要的输入向量。D 算法在 XOR 树等扇出重汇聚结构上存在回溯爆炸的问题。
- PODEM（Path-Oriented Decision Making, Goel 1981）：将搜索空间从电路所有信号线缩小到仅主输入（Primary Inputs）。PODEM 每次决策只尝试设置某个主输入的值，然后通过逻辑仿真推演故障效应能否传播到输出。如果不能，则回溯并尝试其他主输入赋值。这种输入空间搜索策略大幅减少了回溯开销，使中等规模电路的 ATPG 变为实用。
- FAN 和 SOCRATES：在 PODEM 基础上引入蕴涵（Implication）引擎和启发式决策策略，进一步提升回溯效率。

### 测试压缩架构

随着设计规模指数增长，测试数据量和测试时间成为瓶颈。现代测试压缩技术通过片上解压缩硬件将少量顶层输入扩展为大量内部扫描链输入，同时通过片上压缩器将大量扫描链输出压缩为少量顶层输出。

- EDT（Embedded Deterministic Test, Mentor）：在片上嵌入一个环形解压缩器（Ring Generator），将少量外部扫描输入通过线性反馈移位寄存器（LFSR）网络解压为大量内部扫描通道。输出端使用掩码和压缩逻辑精选需要观测的响应位。
- OPMISR+（On-Product Multiple Input Signature Register, Synopsys）：输入端使用广播（Broadcast）和相移（Phase Shifting）网络扩展扫描带宽，输出端使用 MISR（多输入签名寄存器）将测试响应压缩为签名（Signature），仅需在测试结束时读出最终签名比对。

### 故障模型

ATPG 针对特定的故障模型生成测试向量：

- 固定型故障（Stuck-at Fault, SAF）：假设某根信号线永久固化为 0（SA0）或 1（SA1），是最基本的故障模型，覆盖率目标通常 98%+。SAF 能覆盖大多数静态制造缺陷，但无法捕获时序相关缺陷。
- 跳变故障（Transition Fault, TF）：假设某根信号线的 0 到 1 或 1 到 0 跳变太慢，导致目标寄存器无法在时钟周期内捕获正确值。跳变故障在深亚微米工艺中越来越重要，称为 at-speed test。
- 路径延迟故障（Path Delay Fault）：针对特定时序路径的累积延迟故障，需要两个向量对（vector pair）逐路径测试，覆盖率受限于物理路径数量。
- 桥接故障（Bridge Fault）：假设两根相邻信号线之间发生短路，需要物理相邻信息辅助 ATPG。

### ATPG 覆盖率与故障分级

ATPG 覆盖率（Test Coverage）是衡量 DFT 质量的核心指标，定义为已检测故障数占总可检测故障数的比例。ATPG 将故障分为几类：已检测（Detected, DT）、可能检测（Possibly Detected, PT）、不可检测（Undetectable, UD）、ATPG 不可测试（ATPG Untestable, AU）和未测试（Not Detected, ND）。消费电子通常要求固定型故障覆盖率大于等于 98%，汽车电子可能需要大于等于 99%；跳变故障覆盖率通常目标大于等于 85%-90%。提升覆盖率的关键手段包括增加测试点（Test Point）和优化扫描链架构。

### MBIST、LBIST 与边界扫描

- MBIST（Memory Built-In Self-Test）：针对片上 SRAM/DRAM 的内建自测试。BIST 控制器按 March 算法生成地址序列和读写模式，自动对比读出数据与期望值。MBIST 还可以执行修复（Repair），利用冗余行/列替换故障单元。
- LBIST（Logic Built-In Self-Test）：使用片上 PRPG（伪随机序列生成器）产生测试向量，通过扫描链加载，再用 MISR 压缩响应。LBIST 的优势在于上电自检（Power-On Self-Test），无需外部 ATE 设备。现代 LBIST 采用重新播种（Reseeding）策略：在一个测试序列结束后加载新种子值，重复多轮直到覆盖率饱和。MISR 压缩虽是有损的（存在别名概率），但使用 32 位或 64 位 MISR 可将别名概率降至 2^{-32} 以下，在实际工程中可忽略。
- JTAG/IEEE 1149.1 边界扫描（Boundary Scan）：在芯片的 I/O 焊盘和内部核心逻辑之间插入边界扫描单元（BSC），通过 TAP 控制器（Test Access Port）提供的 TDI、TDO、TCK、TMS 和可选的 TRST 五线接口实现对芯片间互连的测试。边界扫描主要用于 PCB 板级互连测试和芯片配置。
- IEEE 1687 IJTAG（Internal JTAG）：将 JTAG 的控制范型扩展到芯片内部，通过分段插入链路（Segment Insertion Bit, SIB）在网络化的仪器接口之间建立动态访问路径，实现对外设 IP 中嵌入的测试和调试仪器的按需访问。

## 关键要点

- 扫描链通过 MUX-DFF 将内部触发器串行化为可控可观察状态，本质是用测试时间换测试覆盖率——可观测性从接近零提升到接近 100%
- ATPG 从 D 算法到 PODEM 的关键突破是将搜索空间从全部信号线缩减到仅主输入，使测试向量生成从 NP 问题变为可实用
- 测试压缩（EDT/OPMISR+）是现代 DFT 的必备技术——不压缩时测试数据量可达数百 Gbits，压缩后通常降低 50-100 倍
- 跳变故障（Transition Fault）的 at-speed 测试在深亚微米工艺中不可忽略，固定型故障覆盖率再高也无法保证芯片在目标频率下正常工作
- MBIST 的 March 算法覆盖了存储器单元间的耦合故障（Coupling Fault）和寻址故障（Address Fault），是现代 SoC 中所有片上存储器的标准测试手段
- JTAG 边界扫描的 TAP 控制器使用 16 状态 FSM，EXTEST 指令驱动互连测试，INTEST 可辅助内部逻辑测试
- DFT 对功能设计的影响包括增加面积（通常 2%-5%）、增加延迟（扫描 MUX 在功能路径上）、需要额外的测试时钟和复位控制
- 扫描链的 DFT DRC 检查是易被忽视但致命的环节——未处理的异步复位、三态总线冲突、门控时钟非透明化都会导致测试向量失效
- IEEE 1687 IJTAG 通过 SIB 实现分级仪器访问，克服了传统 JTAG 扁平化访问在大型 SoC 中的可扩展性问题
- LBIST 的伪随机向量覆盖率受随机困难（Random Resistant）故障制约，重新播种和混合确定性向量是标准解决方案

## 与其他概念的关系

- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — DFT 插入通常在综合之后、物理设计之前进行，综合工具可以执行扫描替换
- [[asic-flow/concepts/clock-tree|时钟树综合（CTS）]] — 扫描模式下时钟树必须满足严格的偏斜要求，否则 at-speed 测试的大量同时翻转会导致 IR 压降失效
- [[asic-flow/concepts/signoff|签核（Signoff）]] — DFT 覆盖率签核（如 98% SAF + 85% TDF）是流片前的硬性指标，测试向量也需要签核级验证
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — 扫描移位期间的功耗远高于功能模式，需要专门的测试功耗分析和降低策略
- [[cross-domain/concepts/low-power-design|跨领域 — 低功耗设计]] — 电源门控模块在测试模式下需要特殊处理，保持寄存器和隔离单元影响 DFT 策略
