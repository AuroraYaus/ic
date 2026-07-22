---
type: concept
aliases:
  - 时序收敛
  - Timing Signoff
  - STA Signoff
  - Timing ECO
tags:
  - asic
  - asic-flow
  - cross-domain
  - timing
  - sta
  - physical-design
source_spec: "Synopsys PrimeTime User Guide; Cadence Tempus Documentation; Bhasker & Chadha, Static Timing Analysis for Nanometer Designs"
---

# 时序收敛（Timing Closure）

时序收敛（Timing Closure）是数字IC物理实现流程中最核心、最耗时的迭代环节，其目标是在所有工艺角（Corner）和工作模式（Mode）下，芯片内的每一条时序路径——寄存器到寄存器（Register-to-Register）、输入到寄存器（Input-to-Register）、寄存器到输出（Register-to-Output）、输入到输出（Input-to-Output）——都满足建立时间（Setup Time）和保持时间（Hold Time）约束。一个未能收敛的设计无法完成 Tape-Out。

## 原理

### 时序收敛的基本流程

时序收敛并非一次性任务，而是一个跨越逻辑综合（Synthesis）、布局（Placement）、时钟树综合（Clock Tree Synthesis, CTS）和布线（Routing）的闭环迭代过程。典型流程从综合开始——综合工具在时序约束（SDC, Synopsys Design Constraints）的驱动下将 RTL 映射到标准单元网表，此时只考虑线负载模型（Wire Load Model, WLM）估算的互联延迟。进入物理设计后，布局阶段获得真实单元位置，CTS 插入时钟缓冲器以平衡时钟偏斜（Clock Skew），布线阶段确定金属层走线并提取精确的寄生参数（RC Extraction），每一个阶段都需要运行静态时序分析（Static Timing Analysis, STA），识别违例路径，根据违例的严重程度和类型决定进入下一个阶段还是回到前一个阶段修复。

### 多工艺角多模式分析

先进工艺下，时序收敛必须在多工艺角多模式（Multi-Corner Multi-Mode, MCMM）框架下进行。不同的 PVT（Process/Voltage/Temperature）条件组合构成工艺角：例如 SS（Slow-Slow, 慢 NMOS 慢 PMOS）角对应最高温度、最低电压，决定了最慢路径（Setup 最差）；FF（Fast-Fast, 快 NMOS 快 PMOS）角对应最低温度、最高电压，决定了最快路径（Hold 最差）。此外还有 TT（Typical-Typical）、SF（Slow-Fast）、FS（Fast-Slow）等角。模式方面包括功能模式（Func Mode）、测试模式（Test/DFT Mode, Scan Shift/Capture）、休眠模式（Sleep Mode）等。MCMM 意味着每个场景都要独立 STA，违例报告和修复需要在所有场景中同时满足。

### 片上变异与裕量缩减

工艺偏差（On-Chip Variation, OCV）是指同一芯片上不同位置的晶体管因光刻、掺杂、刻蚀等制造步骤的随机差异而表现出不同的延迟特性。早期的 OCV 模型使用统一的全局降额因子（Derating Factor）乘以延迟，过于悲观。AOCV（Advanced OCV）引入了基于单元深度和距离的降额表——路径越深、距离越近，变异相关性越强，降额越小。POCV（Parametric OCV / SOCV）进一步使用统计模型，将每个单元的延迟建模为独立的随机变量，通过统计求和（RSS, Root-Sum-Square）而非线性叠加来计算路径延迟的方差。最先进的 LVF（Liberty Variation Format）将变异信息直接嵌入标准单元库的 Liberty（.lib）文件中，提供每个单元每种时序弧（Timing Arc）的均值（μ）和标准差（σ），使 STA 工具能够进行真正的统计时序分析（Statistical STA, SSTA）。

### 串扰与IR-drop对时序的影响

串扰（Crosstalk）由相邻金属线之间的耦合电容引起。当一根线（Aggressor，攻击线）发生跳变时，通过耦合电容对相邻线（Victim，受害线）注入电荷，导致受害者信号的到达时间提前或推迟——这被称为串扰引起的延迟变化（Crosstalk-Induced Delay Change）。在深亚微米工艺中，金属线间距缩小、纵横比增大，耦合电容占总电容的比例显著上升，串扰效应已不可忽略。

IR-drop（电压降）是电源分配网络（Power Delivery Network, PDN）中不可避免的现象。当大量标准单元同时开关时，电流流过 PDN 的寄生电阻和电感，导致实际到达单元电源端子的电压低于理想 VDD（IR-drop 中的 "I" 即电流，"R" 即电阻）——这称为静态 IR-drop；瞬态电流尖峰引起的瞬时电压跌落则称为动态 IR-drop（di/dt 效应）。晶体管在较低的 VDD 下驱动能力减弱、延迟增加，因此严重 IR-drop 区域的时序路径会出现意料之外的 Setup 违例，是 Signoff 阶段最隐蔽的时序问题来源之一。

### ECO修复策略

时序违例的修复由轻到重分为多个层级。最轻量的是工程变更指令（Engineering Change Order, ECO）：不改变布局的大结构，仅通过替换驱动能力更强的单元（Size Up）、插入缓冲器（Buffer Insertion）、调整单元位置（Cell Relocation）等局部操作修复违例。更重的修复需要重新 CTS 或重新 Placement。Setup 违例的修复手段包括：使用更低 Vth 的单元（HVT → SVT → LVT，以漏电换速度）、分解大扇出网络（High Fanout Net Synthesis）、利用有用偏斜（Useful Skew）——故意将时钟做偏以平衡前后级的延迟差。Hold 违例通常通过插入延迟单元（Delay Cell）或缓冲器对来修复。Margin Reduction（裕量缩减）是时序收敛后期的重要策略：去除过度悲观的设计裕量（如过大的时钟不确定性、过保守的 OCV 降额），使工具在真实约束下工作。

## 关键要点

- 时序收敛是横跨综合、布局、CTS、布线的迭代闭环，每步都需 STA 验证，Setup 违例需回到前序阶段修复
- MCMM 要求在 SS/FF/TT/SF/FS 等多个 PVT 角和 Func/Test/Sleep 等多个模式下同时满足时序
- OCV → AOCV → POCV → LVF 的演进反映了从保守降额到统计建模的方法论转变，减少了过度设计
- 串扰延迟变化使得同一路径在不同邻居活动组合下的延迟不同，需要基于耦合电容和开关窗口（Timing Window）的 STA 分析
- IR-drop 导致局部 VDD 降低、单元延迟增加，可能引起 Signoff 后布局布线已完工时才发现的新时序违例
- Useful Skew 策略通过主动制造时钟偏移来平衡相邻寄存器级的延迟差，是 Setup 收敛的利器
- Setup/Hold 违例修复手段不同：Setup 侧重加速数据路径（低 Vth、减小负载），Hold 侧重延迟数据路径（插入缓冲器/延迟单元）
- ECO 是时序收敛后期的主要修复手段，强调局部修改、最小化对已完成布线的影响
- 时序收敛的核心矛盾始终是 PPA（Performance/Power/Area）的三角权衡：加速路径意味着更大的单元面积和更高的漏电流

## 与其他概念的关系

- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — 综合阶段的 WLM 时序估算决定网表质量，好的起始点大幅降低物理阶段的时序收敛难度
- [[asic-flow/concepts/floorplanning|布局规划（Floorplanning）]] — 宏单元和标准单元的物理位置决定了关键路径的线长和延迟上限
- [[asic-flow/concepts/cts|时钟树综合（CTS）]] — CTS 直接决定时钟偏斜和不确定性，是 Setup/Hold 违例分析的核心变量
- [[asic-flow/concepts/signoff|物理签核（Signoff）]] — Timing Signoff 是 Tape-Out 前的最终 STA 检查，包括 Setup、Hold、DRV、Noise 等多维度验证
- [[cross-domain/low-power-design|低功耗设计]] — 多电压域设计引入 Level Shifter 和多个电压轨，增加了 MCMM 场景数量和时序收敛复杂度
- [[concepts/semiconductor-basics|半导体基础]] — PVT 变异的物理根源：掺杂浓度偏差、氧化层厚度波动、温度对载流子迁移率的影响
