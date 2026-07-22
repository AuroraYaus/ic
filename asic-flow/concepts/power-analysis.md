---
type: concept
aliases:
  - Power Analysis
  - 功耗分析
tags:
  - asic
  - asic-flow
  - power
source_spec: "Rabaey Digital Integrated Circuits Ch.5, Keating Low Power Methodology Manual (LPMM), Synopsys PrimePower/PTPX User Guide, IEEE 1801 UPF Standard"
---

# 功耗分析（Power Analysis）

功耗分析（Power Analysis）贯穿 ASIC 设计全流程——从 RTL 级功耗估算到 Signoff 级精确功耗签核——其目标是在设计的每个阶段准确评估并优化芯片的能量消耗。功耗已成为先进工艺节点下与性能同等重要的第一级设计约束。

## 原理

### 动态功耗分解

动态功耗（Dynamic Power）由两部分组成。开关功耗（Switching Power）是负载电容充放电所消耗的能量：$P_{switch} = \frac{1}{2} \alpha C_L V^2 f$，其中 $\alpha$ 为活动因子（每周期平均翻转概率），$C_L$ 为负载电容，$V$ 为电源电压，$f$ 为时钟频率。电压项呈平方关系——将电压从 1.0V 降至 0.9V 即可减少约 19% 的开关功耗，这是架构层面最有效的功耗杠杆。内部功耗（Internal Power / Cell Internal Power）是标准单元内部在输入跳变时从电源到地的短暂直流通路（Short-Circuit / Crowbar Current）以及内部节点充放电所消耗的能量，在 .lib 中建模为每次翻转的能量乘以翻转率。内部功耗依赖于输入过渡时间（Slew）和输出负载——过渡时间越长，PMOS 和 NMOS 同时导通的时间窗口越大。

动态功耗分析需要活动因子数据，可通过仿真波形（VCD: Value Change Dump，记录真实仿真中每个信号的翻转事件，最精确）或 SAIF（Switching Activity Interchange Format，紧凑的翻转统计）反标获得。

### 静态/漏电功耗

静态功耗（Static Power / Leakage Power）是电路在无信号跳变时消耗的能量，在先进工艺（28nm 及以下）中已与动态功耗量级相当。三个主要漏电机制为：亚阈值漏电（Subthreshold Leakage）——$V_{GS} < V_{th}$ 时仍有微弱源漏电流，随 $V_{th}$ 降低呈指数增长，是先进工艺中最大的漏电来源；栅极漏电（Gate Leakage）——电荷隧穿薄栅氧层，在 <45nm 节点显著，通过高 K 金属栅极（HKMG）技术缓解；结漏电（Junction Leakage）——源漏与衬底间反向偏置 PN 结产生，通常 <1% 总量。漏电高度依赖温度和工艺角——温度每升高 25 度可翻倍，FF 角 +125 度结温下可达标称值的 5-10 倍。

### 低功耗技术

**时钟门控（Clock Gating）**是降低动态功耗的最有效片上技术。与门时钟门控（AND-Based）简单但使能信号可能与时钟沿竞争产生毛刺；集成时钟门控单元（ICG-Based）使用锁存器+与门——锁存器在时钟低电平时捕捉使能信号，上升沿后锁存关闭保，使能与门输出的时钟沿干净无毛刺——ICG 是标准做法，EDA 工具可自动插入。

**电源门控（Power Gating）**通过关断整个模块的电源网络将漏电降至接近零，由 IEEE 1801 UPF 标准定义三大辅助单元：电源开关（Power Switch）——大尺寸 PMOS/NMOS 作为电源轨开关，分 header 型（VDD 侧）和 footer 型（VSS 侧）；隔离单元（Isolation Cell）——关断域的浮空输出可在常开域造成短路电流，隔离单元钳位输出到确定电平；保持寄存器（Retention Register）——关断前保存关键状态到常开供电的保持锁存器，上电后恢复。

**多阈值电压（Multi-Vth）**策略：LVT（低 Vth，高速高漏电）用于关键路径，SVT（标准 Vth，平衡）用于常规路径，HVT（高 Vth，低速低漏电）用于非关键路径——典型设计中 HVT 占比 70-80%。**动态电压频率调节（DVFS）**在运行时根据负载动态调整电压和频率（$f_{max} \propto V_{DD}$），需要电平移位器（Level Shifter）处理跨电压域信号。自适应电压调节（AVS）使用工艺监控器 + 温度传感器闭环最小化电压余量。

## 关键要点

- 开关功耗 $P_{switch} = \frac{1}{2} \alpha C_L V^2 f$，电压项平方关系——降低电压是最有效的架构级功耗控制手段
- 亚阈值漏电是先进工艺静态功耗最大来源，栅极漏电通过 HKMG 缓解，结漏电占比最小
- 时钟门控（ICG，非 AND）是降低动态功耗的最有效技术——时钟 $\alpha=1$ 功耗占比极高
- 电源门控通过关断电源网络将漏电降至零，需要 UPF 定义的 Power Switch、Isolation Cell、Retention Register
- Multi-Vth 混合使用（LVT 关键路径 / HVT 非关键路径，HVT 占比 70-80%）是速度-漏电平衡的核心手段
- DVFS + AVS 在运行时调节电压和频率，需要 Level Shifter 处理跨电压域信号
- 功耗估计从 RTL 到 Signoff 精度递增：早期功率预算（PTPX/PowerArtist）-> 门级 VCD 反标 -> Signoff 级全角全模精确签核

## 与其他概念的关系

- [[asic-flow/concepts/clock-tree|时钟树综合（CTS）]] — 时钟树功耗占芯片动态功耗的 30-40%，时钟门控是降低时钟功耗的核心手段
- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — 综合工具自动插入 ICG 并执行 Multi-Vth 单元替换，是功耗优化的第一战场
- [[asic-flow/concepts/signoff|签核（Signoff）]] — IR Drop 签核和功耗签核是流片前的关键步骤
- [[cross-domain/low-power-design|低功耗设计]] — IEEE 1801 UPF 标准定义了跨流程的低功耗意图描述，从 RTL 到 Signoff 统一表达
