---
type: concept
aliases:
  - Signoff
  - 签核
  - Tape-Out
  - Sign-off
tags:
  - asic
  - asic-flow
  - signoff
  - timing
  - physical-verification
source_spec: "Synopsys PrimeTime User Guide, Cadence Tempus User Guide, Cadence Voltus User Guide, Mentor Calibre User Guide"
---

# 签核（Signoff）

签核（Signoff）是 ASIC 设计流程中的最终质量关卡——在设计数据送交晶圆厂（Tape-Out）制造光罩（Mask）之前，必须在时序、功耗、物理验证和逻辑等价性等维度通过一整套极其严格的质量检查标准。签核失败将直接导致流片失败——芯片返回时功能缺陷或无法在目标频率工作——这种成本在先进工艺节点（5nm/3nm）中可达数千万美元。签核的工具链独立于实现工具链，使用专用签核级 EDA 工具：时序签核用 PrimeTime/Tempus，物理验证用 Calibre/IC Validator，功耗签核用 Voltus/RedHawk，等价性检查用 Formality/Conformal，IR 压降签核用 RedHawk/Voltus。

## 原理

### 时序签核（Timing Signoff）

时序签核是签核流程中最核心的部分，其片上偏差（On-Chip Variation, OCV）建模精度演进路径展示了工艺缩放对签核方法的驱动。

**OCV（Basic OCV）**：最基础的偏差建模——对发射时钟路径和数据路径施加统一的 +X% 延迟增长（Late Derate），对捕获时钟路径施加统一的 -Y% 延迟减少（Early Derate），如 `set_timing_derate -late 1.10 -early 0.90`。OCV 简单但极端悲观——将片上所有门都当作全局最坏偏差对待，实际上空间邻近的门偏差具有相关性。在先进工艺中 OCV 悲观度过高导致无法收敛，需要更精细的建模。

**AOCV（Advanced OCV）**：根据路径逻辑深度使用可变降额因子。浅路径（逻辑级数少）中随机偏差不能被统计平均抵消，需要较大降额余量；深路径（逻辑级数多）中随机偏差有平均化效应，降额余量可减小。AOCV 通过深度查表（Stage-Based Derate Table）获取每条路径的降额值，比统一降额乐观 15%-25%，已广泛应用于 28nm-7nm 节点。

**POCV/SOCV（Parametric/Statistical OCV）**：将延迟建模为概率分布（通常为高斯分布，参数化为均值 $\mu$ 和标准差 $\sigma$），而非简单的降额因子。每条路径的总延迟方差等于各级门延迟方差之和（独立随机变量假设），总标准差 $\sigma_{total} = \sqrt{\sum_i \sigma_i^2}$。POCV 使用 $3\sigma$ 或更严格的置信区间，避免了 OCV 将不同深度路径统一对待的过度悲观。POCV 已成为 7nm 以下节点的标准签核方法。

**LVF（Liberty Variation Format）**：POCV 的进化——将 $\sigma$ 信息从外部 sigma 文件集成到 .lib 工艺库本体内，每个时序弧（Timing Arc）的 $\sigma$ 作为 delay/slew 的函数存储在 LVF 扩展的 .lib 中。LVF 支撑 5nm/3nm 签核。

### IR 压降签核

IR 压降（IR Drop）是供电网络（Power Delivery Network, PDN）中由于金属线电阻导致的电压损失——$V_{drop} = I \times R$，其中 $I$ 为流过供电路径的电流，$R$ 为电源网格的寄生电阻。**静态 IR 压降**分析平均电流下的电压分布，用于评估供电网络的直流稳健性——通常要求静态 IR Drop < 2%-3% VDD。**动态 IR 压降**分析瞬态电流波动的电压响应，考虑了标准单元在时钟沿处同时翻转产生的电流尖峰（di/dt）——动态 IR Drop 可达静态的 2-5 倍，是高频设计的瓶颈。片上解耦电容（On-Die Decoupling Capacitor, DECAP）提供瞬态电流、抑制电压毛刺。IR 压降过大导致门延迟增加（电压降低增加了门延迟），在 STA 中通过电压-延迟敏感度反标来建模。

### 电迁移签核

电迁移（Electromigration, EM）是金属原子在高电流密度下因电子"风"力作用发生定向迁移的物理现象——导致金属线出现空洞（Void）而断路，或堆积（Hillock）而短路。**DC EM**（平均电流密度限制）规定直流或平均电流密度不超过金属层的 EM 极限值（如铜互连 10-20 mA/µm²）。**AC/RMS EM** 考虑双向电流的愈合效应——交流电流中电子来回撞击使原子有较短净迁移，RMS 电流限制比 DC 限制宽松。**Signal EM** 考虑信号线的瞬态大电流（如大扇出时钟缓冲器输出），需要瞬态波形分析而非平均电流。EM 签核工具（Voltus/RedHawk）基于每个金属段的电流密度与对应层的 EM Design Rule 对比，标记违例段。

### 等价性检查签核

逻辑等价性检查（Logic Equivalence Checking, LEC）形式验证综合/优化/ECO 后的门级网表在功能上完全等价于原始 RTL。LEC 将时序元件按名称或用户映射确认为比较点（Compare Points），然后将 RTL 和网表的组合逻辑锥（Logic Cone）的布尔函数逐一进行 SAT 求解器验证。LEC 是防止综合优化（如资源共享、逻辑重构）不经意改变功能的安全网——任何结构性的 FSM 重编码、门控时钟插入、ECO 手动网表修改都必须在 LEC 通过后才可签核。LEC 是签核流程中唯一不需测试向量的验证手段。

### 全工艺角（PVT）覆盖

最终签核必须在所有工艺角（Process Corner）、电压（Voltage）和温度（Temperature）组合（统称 PVT 角）下通过。典型多角签核矩阵包括：SSGNP（Slow-Slow, 高 Vth, 低 VDD, 高温 — 最坏 Setup）、FFGNP（Fast-Fast, 低 Vth, 高 VDD, 低温 — 最坏 Hold）、以及 Typ 25°C。先进工艺签核角可达 20-50 个 PVT 组合，每个角都需要完整的 STA + IR + EM，计算资源需求极大。多角并行化和增量 STA 技术（仅重新分析改变的部分）是关键效率优化手段。

## 关键要点

- 签核工具链独立于实现工具链——PrimeTime 签核 STA, Calibre 签核 DRC/LVS, Voltus 签核 IR/EM——"签核级"意味着晶圆厂认可的分析精度
- OCV 演进路径 OCV -> AOCV -> POCV -> LVF 是从统一悲观降额到概率统计建模的递进——每代方法消除 15%-25% 过度悲观，在先进节点中是不可或缺的收敛手段
- 动态 IR 压降可达静态的 2-5 倍，DECAP 密度和布局是抑制动态 IR 的核心设计手段——需要瞬态向量（Vectorless 或 VCD-driven）分析
- 电迁移签核分为 DC EM、AC/RMS EM 和 Signal EM，三者基于不同的电流计算模型——铜互连 EM 极限约 10-20 mA/µm²
- LEC 是唯一不需测试向量的签核项——等价性检查通过 SAT 形式化验证 RTL-vs-Gate 功能一致
- PVT 角全覆盖是 Signoff 的计算资源瓶颈——先进工艺 20-50+ 角往往需要大规模并行计算集群支持
- Timing ECO 是 Signoff 中的高频活动——在签核 STA 发现违例后通过最小侵入调整修复，需反复迭代直到全角全模式收敛
- Setup 和 Hold 修复存在根本冲突——插入缓冲器修复 Hold 会增加线长侵蚀 Setup，通常优先修复 Setup 再用有用偏斜/缓冲器修复 Hold

## 与其他概念的关系

- [[asic-flow/concepts/static-timing-analysis|静态时序分析（STA）]] — STA 是时序签核的核心分析引擎，PrimeTime/Tempus 的签核级 STA 分析精度满足晶圆厂认可标准
- [[asic-flow/concepts/physical-verification|物理验证（Physical Verification）]] — DRC/LVS 是 Signoff 中的强制物理验证项，使用 Calibre/IC Validator 等专用签核工具
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — 功耗签核（IR Drop + EM + Total Power）与功耗分析共用数据集但使用签核级精度引擎
- [[verification/concepts/formal-verification|形式验证（Formal Verification）]] — LEC 等价性检查是形式验证在 ASIC 流程中的关键应用，是签核的必选项
- [[cross-domain/concepts/timing-closure|时序收敛（Timing Closure）]] — Signoff 是时序收敛的最终裁判——Signoff 通过即完成 Timing Closure
