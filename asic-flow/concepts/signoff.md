---
type: concept
aliases:
  - Signoff
  - 签核
  - Design Signoff
tags:
  - asic
  - asic-flow
  - signoff
  - timing
  - physical-verification
source_spec: "Synopsys PrimeTime/StarRC/ICV User Guides, Cadence Tempus/Quantus/PVS User Guides, TSMC/Samsung Foundry Signoff Documentation"
---

# 签核（Signoff）

签核（Signoff）是 ASIC 设计流程中的最终质量关卡——在设计数据送交晶圆厂（Tape-Out）之前，必须在时序、功耗、物理验证和逻辑等价性等维度通过一整套极其严格的质量检查标准。签核的合格不是基本满足而是必须在所有 PVT 角（Corner）的所有模式下，对每条路径、每根线网、每个制造规则都通过。签核失败将直接导致流片失败——芯片返回时功能缺陷或无法在目标频率工作——这种成本在先进工艺节点中可能高达数千万美元。

## 原理

### 时序签核

时序签核（Timing Signoff）是签核流程中最核心、最复杂的部分。它的演进路径反映了工艺偏差建模精度的持续提升：

- OCV（On-Chip Variation）：最基础的偏差建模——对发射时钟路径和数据路径施加统一的延迟增长（Late Derate），对捕获时钟路径施加延迟减少（Early Derate）。例如 `set_timing_derate -late 1.10 -early 0.90`。OCV 简单但极端悲观——将所有路径都当作最坏偏差来处理。
- AOCV（Advanced OCV）：根据路径深度和物理距离使用可变的降额因子。浅路径（逻辑级数少）的随机偏差不能被平均值抵消，需要更大的降额余量；深路径（逻辑级数多）的随机偏差有平均化效应，降额余量可以减小。AOCV 通过查表（Stage-Based Derate Table）来获取每条路径的降额值，比统一降额乐观 15%-25%。
- POCV（Parametric OCV）：基于统计的片上偏差建模。POCV 将每个单元和每根线网的延迟建模为服从高斯分布的随机变量（均值为标准值、标准差通过 SPICE 蒙特卡洛仿真确定），然后通过统计 STA（SSTA）引擎计算目标良率（如 3-sigma / 99.7% 或 4-sigma / 99.99%）下的最坏 slack。
- LVF（Liberty Variation Format）：由 Liberty 标准扩展的偏差描述格式。LVF 在标准 .lib 文件中嵌入了每个单元在不同输入过渡时间和输出负载下的矩（均值和标准差）数据，使 SSTA 引擎可以直接使用工艺库中的原生偏差信息。

时序签核的输入包括：CTS 后反标的 SPEF（Standard Parasitic Exchange Format）寄生参数文件、包含所有 PVT 角的 Liberty 库、多模约束 SDC 文件。签核工具（PrimeTime、Tempus）在全角全模下执行详尽的建立/保持检查。

### IR 压降签核

IR 压降签核确保芯片的电源分配网络（Power Distribution Network, PDN）能够为所有标准单元和宏单元提供稳定的供电电压。IR 压降超过一定阈值（通常目标小于 3% V_DD 静态、小于 5%-8% V_DD 动态）将导致局部电压降过低，使门延迟显著增大，间接导致时序违例甚至功能失效。

静态 IR Drop 是电源网络在稳定的平均电流下的压降，取决于电源网格的 DC 电阻和平均电流分布。动态 IR Drop（di/dt Drop）是大量门同时翻转引发的瞬时电流突变在电源网格寄生电感上产生的电压尖峰（L * di/dt），以及寄生 RC 网络上瞬态电流的充电延迟。动态 IR 通常比静态 IR 更大且更难以分析，需要基于真实翻转波形的瞬态仿真（RedHawk、Voltus）。

### 电迁移签核

电迁移（Electromigration, EM）是金属导线在高电流密度下长期运行后发生原子迁移导致导线断开（Open）或短路（Short）的物理失效机制。EM 签核检查电源网格和信号线网的电流密度是否超过工艺规定的极限值（J_max）。

电源网络 EM：电源和地网络承载持续或周期性的大电流，是 EM 失效的高风险区域。Signoff 工具通过反标真实电流波形（来自 VCD）计算平均电流密度（RMS 或 Average Current）与工艺 EM 极限比较。信号网络 EM：高速时钟和数据信号的频繁翻转也会产生 EM 风险，尤其是最小宽度和最小间距的高频走线。先进工艺节点中，信号线 EM 已经与电源 EM 同等重要。

### 形式等价检查

形式等价检查（Logic Equivalence Checking, LEC / Formal Equivalence Checking, FEC）使用形式验证方法（而非仿真）在数学上证明两个设计表示——如综合前的 RTL 和综合后的门级网表——在功能上完全等价。

LEC 工具（如 Synopsys Formality、Cadence Conformal LEC）将 RTL 和门级网表都转化为布尔逻辑表达式，逐对比较寄存器间的组合逻辑功能。关键检查点包括：RTL vs Gate（综合后）验证综合的优化变换没有改变功能；Gate vs Gate（扫描插入后）验证 DFT 扫描替换没有破坏功能逻辑；Gate vs Gate（CTS 后，P&R 后）验证物理设计阶段的优化没有改变逻辑功能；Gate vs Gate（ECO 后）验证 ECO 的局部修改没有引入功能偏差。

LEC 的关键挑战在于名称映射（Name Mapping）问题——综合和 P&R 可能修改寄存器/端口名称，LEC 需要通过功能签名（Functional Signature）而非名称来实现对应。

### 签核的全角全模需求

签核不是在一个角下一个模式下的单项检查。一个现代 SoC 设计可能包含：多个 PVT 角（如 SS/125C/0.81V、FF/-40C/0.99V、TT/25C/0.90V）；多个工作模式（功能模式、扫描移位模式、扫描捕获模式、MBIST 模式、睡眠模式）；寄生参数的角（C_worst/C_best/RC_worst/RC_best——金属宽度和厚度的工艺偏差导致寄生 RC 参数有最坏组合）；以及 Combinational RC Corners（R 和 C 不在同一工艺角下同时最坏）。全角全模的组合爆炸是签核工具面临的最大工程挑战——100+ 个角并行分析的 DMSA（Distributed Multi-Scenario Analysis）是标配。

## 关键要点

- 签核是在 Tape-Out 前，在所有 PVT 角的所有模式下对所有路径和网络进行的最严格质量验证——一次签核失败可能导致数千万美元的流片损失
- 时序签核的精度演进：OCV（统一降额、最悲观）到 AOCV（路径深度相关、中等精度）到 POCV（统计分布、高精度）到 LVF（Liberty 原生偏差、最高精度）
- IR 压降签核的目标是确保芯片任何位置的局部 V_DD 不低于额定值——静态 IR 小于 2%-3%、动态 IR 小于 5%-8%
- 电迁移（EM）在电源网络和信号网络中均可能发生——电源网 EM 由连续/周期性大电流驱动，信号网 EM 由高频翻转驱动
- 形式等价检查（LEC）通过数学证明而非仿真来验证 RTL 与门级网表的功能等价——覆盖 100% 输入空间，这是仿真无法企及的
- SPEF（Standard Parasitic Exchange Format）是签核级寄生参数的标准格式，包含每条线网的分布式 RC 网络，是时序和 IR 签核的共同数据基础
- 寄生参数的角（R/C Corner）与 PVT 角独立——需要组合形成 Multi-Corner 分析空间，R 和 C 在不同工艺偏差下表现出不相关的极值
- 全角全模签核的计算量巨大——一个典型 SoC 的完整签核可能需要数千 CPU 小时，DMSA 并行化和增量签核（Incremental STA）是效率关键
- Signoff 工具（PrimeTime/Tempus）的 Gold Standard 地位来自其与晶圆厂的认证流程——工艺库和签核工具的版本必须匹配晶圆厂认证清单
- 时序、功耗、物理验证和 LEC 四大签核维度必须全部 GREEN 才能释放 GDSII——任何一个维度的失败都意味着需要重新迭代

## 与其他概念的关系

- [[asic-flow/concepts/static-timing-analysis|静态时序分析（STA）]] — 时序签核是 STA 的最严格应用，OCV 到 AOCV 到 POCV 到 LVF 的演进体现了签核精度的持续提升
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — IR 压降和电迁移签核是功耗分析的最终验证阶段，VCD 反标的准确度决定签核结果的可信度
- [[asic-flow/concepts/physical-verification|物理验证（Physical Verification）]] — DRC/LVS 签核与功耗/时序签核并行，所有签核维度都通过后才能 Tape-Out
- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — 综合后的形式等价检查（RTL vs Gate LEC）是签核的第一个正式关卡
- [[asic-flow/concepts/dft|可测试性设计（DFT）]] — 扫描链插入后的 LEC 和测试模式的时序签核是流片前的必需步骤
