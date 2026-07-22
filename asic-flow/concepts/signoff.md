---
type: concept
aliases:
  - Signoff
  - 签核
tags:
  - asic
  - asic-flow
  - signoff
source_spec: "Synopsys PrimeTime/StarRC/ICV User Guides, Cadence Tempus/Quantus/PVS User Guides, TSMC/Samsung Foundry Signoff Documentation"
---

# 签核（Signoff）

签核（Signoff）是 ASIC 设计流程中的最终质量关卡——在设计数据送交晶圆厂（Tape-Out）之前，必须在时序、功耗、物理验证和逻辑等价性等维度通过一整套极其严格的质量检查标准。签核失败将直接导致流片失败——芯片返回时功能缺陷或无法在目标频率工作——这种成本在先进工艺节点中可高达数千万美元。

## 原理

### 时序签核

时序签核（Timing Signoff）是签核流程中最核心的部分，其建模精度演进路径如下：

- **OCV（On-Chip Variation）**：最基础的偏差建模——对发射时钟路径和数据路径施加统一的 +X% 延迟增长（Late Derate），对捕获时钟路径施加 -Y% 延迟减少（Early Derate）。例如 `set_timing_derate -late 1.10 -early 0.90`。OCV 简单但极端悲观——将所有路径都当作最坏偏差，实际上同一条路径上的门在物理上相近，偏差应具相关性。
- **AOCV（Advanced OCV）**：根据路径深度使用可变降额因子。浅路径（逻辑级数少）随机偏差不能被平均抵消，需要更大降额余量；深路径（逻辑级数多）随机偏差有平均化效应，降额余量可减小。AOCV 通过查表（Stage-Based Derate Table）获取每条路径的降额值，比统一降额乐观 15-25%。
- **POCV（Parametric OCV）**：基于统计的片上偏差建模。将每个单元和每根线网的延迟建模为服从高斯分布的随机变量（均值为标准值、标准差通过 SPICE 蒙特卡洛仿真确定），通过统计 STA（SSTA）引擎计算目标良率下的最坏 slack。
- **LVF（Liberty Variation Format）**：在标准 .lib 文件中嵌入每个单元在不同输入过渡时间和输出负载下的矩（均值和标准差）数据，以及空间相关性和非高斯分布信息，使 SSTA 引擎可直接使用工艺库中的原生偏差信息。

时序签核的输入包括：CTS 后反标的 SPEF 寄生参数文件、包含所有 PVT 角的 Liberty 库、多模约束 SDC 文件。签核工具（PrimeTime、Tempus）在全角全模下执行详尽的建立/保持检查。

### IR 压降签核与电迁移签核

IR 压降签核确保电源分配网络（PDN）为所有单元提供稳定供电。静态 IR Drop 取决于电源网格的 DC 电阻和平均电流分布；动态 IR Drop（di/dt Drop）是大量门同时翻转引发的瞬时电流突变在寄生电感上产生的电压尖峰（$L \cdot di/dt$），需要基于真实翻转波形的瞬态仿真（RedHawk、Voltus）。Signoff 目标通常是静态 IR < 2-3%、动态 IR < 5-8% 的 $V_{DD}$。

电迁移（Electromigration, EM）是金属导线在高电流密度下长期运行后原子迁移导致断路或短路的物理失效机制。电源网络 EM 由持续/周期性大电流驱动——通过反标真实电流波形计算平均电流密度与工艺 $J_{max}$ 比较；信号网络 EM 由高频翻转驱动，在先进工艺节点中已与电源 EM 同等重要。

### 形式等价检查

形式等价检查（Logic Equivalence Checking, LEC / FEC）使用形式验证方法在数学上证明两个设计表示在功能上完全等价——覆盖 100% 输入空间，仿真无法企及。关键检查点：RTL vs Gate（综合后，验证优化变换未改变功能）、Gate vs Gate（扫描插入后 / CTS 后 / P&R 后 / ECO 后）。LEC 工具（Formality、Conformal LEC）将 RTL 和门级网表都转化为布尔逻辑表达式，逐对比较寄存器间的组合逻辑功能。关键是解决名称映射问题——综合和 P&R 可能修改寄存器/端口名称，LEC 通过功能签名而非名称实现对应。

### 签核的全角全模需求

签核必须在所有 PVT 角的所有模式下对所有路径和网络进行检查。一个现代 SoC 可能涉及：多个 PVT 角（SS/125C/0.81V、FF/-40C/0.99V、TT/25C/0.90V 等）、多个工作模式（功能/扫描移位/扫描捕获/MBIST/睡眠/各 DVFS 性能点）、寄生参数角（C_worst/C_best/RC_worst/RC_best）、RC Corners（R 和 C 在不同工艺偏差下可能表现出不相关的极值）。最坏情况建立检查为低 V、高 T、慢工艺；最坏情况保持检查为高 V、低 T、快工艺。全角全模组合爆炸使 DMSA（Distributed Multi-Scenario Analysis）并行分析成为标配。

## 关键要点

- 签核是 Tape-Out 前的最终质量验证——一次失败可导致数千万美元流片损失
- 时序签核精度演进：OCV（统一降额）-> AOCV（路径深度相关）-> POCV（统计分布）-> LVF（Liberty 原生偏差）
- 静态 IR Drop < 2-3%、动态 IR Drop < 5-8% 是标准 Signoff 目标，超出范围意味着局部逻辑可能无法在目标频率工作
- EM 在电源网络（由持续大电流驱动）和信号网络（由高频翻转驱动）中均可能发生，两者同等重要
- LEC 通过数学证明而非仿真验证功能等价——覆盖 100% 输入空间
- SPEF 是签核级寄生参数的标准格式，包含分布式 RC 网络，是时序签核和 IR 签核的共同数据基础
- 全角全模签核计算量巨大——DMSA 并行化和增量 STA 是效率关键
- Signoff 工具（PrimeTime/Tempus）的 Gold Standard 地位来自其与晶圆厂的认证流程

## 与其他概念的关系

- [[asic-flow/concepts/static-timing-analysis|静态时序分析（STA）]] — 时序签核是 STA 的最严格应用，OCV->AOCV->POCV->LVF 的演进体现签核精度提升
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — IR 压降和 EM 签核是功耗分析的最终验证阶段
- [[asic-flow/concepts/physical-verification|物理验证（Physical Verification）]] — DRC/LVS 签核与功耗/时序签核并行，全部通过才能 Tape-Out
- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — 综合后的 RTL vs Gate LEC 是签核的第一个正式关卡
