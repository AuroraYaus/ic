---
type: concept
aliases:
  - 亚稳态
  - MTBF
  - Synchronizer Failure
  - Bistable
tags:
  - asic
  - basics
  - metastability
  - cdc
source_spec: "Kleeman & Cantoni, Metastable Behavior in Digital Systems (IEEE Design & Test 1987); Ginosar, Metastability and Synchronizers: A Tutorial (IEEE 2011)"
---

# 亚稳态（Metastability）

亚稳态（Metastability）是数字电路中所有同步器设计的根本物理依据，也是跨时钟域设计（CDC）、异步复位以及任何异步信号采样场景必须面对的基础问题。亚稳态的本质是双稳态存储元件（交叉耦合反相器构成的触发器）在输入信号于采样窗口内变化时，输出进入一个不稳定的中间状态，需要一段随机的解析时间（Resolution Time）才能衰减到确定的逻辑电平。

## 原理

### 双稳态元件的亚稳态物理机制

数字电路的基本存储单元基于双稳态（Bistable）电路：由两个交叉耦合反相器构成的正反馈系统。一个双稳态系统有两个稳定平衡点（分别对应逻辑 0 和逻辑 1）和一个不稳定的亚稳态平衡点（Metastable Equilibrium Point，通常位于 $V_{DD}/2$ 附近）。在亚稳态点 $V_{in} = V_{out} = V_{mid} \approx V_{DD}/2$ 处，两个反相器均处于线性增益区，正反馈净增益为零——系统无法自主驱动到稳定状态。任何微小噪声扰动最终推动输出走向 0 或 1，但这个过程可能需要任意长的时间。

解析过程可用一阶小信号模型描述：$\Delta V(t) = \Delta V(0) \cdot e^{t/\tau}$，其中 $\tau$ 是再生时间常数（Regeneration Time Constant），由晶体管跨导（$g_m$）和节点电容决定，先进工艺中典型值约 1-5 ps。FinFET 因更高 $g_m$ 而 $\tau$ 更小——从平面 CMOS 到 FinFET，$\tau$ 的降低提升了同步器可靠性。

### MTBF 公式与同步器设计

同步器的可靠性由平均故障间隔时间（Mean Time Between Failures, MTBF）量化：

$$MTBF = \frac{e^{t_{res}/\tau}}{f_{clk} \cdot f_{data} \cdot T_0}$$

参数含义：$t_{res}$（解析时间）——允许亚稳态解析的最大时间窗口（时钟周期减去第二级 FF 的建立时间和偏斜），在指数项中，对 MTBF 影响最为剧烈；$\tau$（再生时间常数）——工艺决定，FinFET 约 1-3 ps；$f_{clk}$（目标时钟频率）；$f_{data}$（源数据变化频率）；$T_0$（采样窗口参数）——与建立-保持窗口成正比，典型值 $10^{-8}$ 至 $10^{-10}$ 秒。

以典型 28nm 参数为例：$f_{clk} = 1\text{ GHz}$，$f_{data} = 100\text{ MHz}$，$\tau = 3\text{ ps}$，$T_0 = 50\text{ ps}$。2-FF 链提供约 $t_{res} \approx 950\text{ ps} \approx 317\tau$ 的解析时间，MTBF 约 $10^{30}$ 年以上——远超芯片寿命。但若频率升至 10 GHz（$t_{res} \approx 80\text{ ps} \approx 27\tau$），MTBF 急剧下降至数百毫秒——需额外增加同步器级数。

### 同步器级数确定与工程实践

增加同步器级数是碾压性（指数级）的改善——每增加一级延长一个周期 $t_{res}$，MTBF 指数增长。对于 GHz 级 SoC，2 级通常足够；对于 >5-10 GHz 高频或汽车 ASIL-D（目标 MTBF > $10^9$ 小时）、航空航天等极高可靠性应用，需 3+ 级。同步器级间严格禁止组合逻辑——任何组合逻辑都可能产生毛刺破坏功能。各级触发器需紧密物理放置，使用完全相同的单元类型（同一 VT 类别、同一驱动强度），走线尽量短直。关键 CDC 路径中，同步器 FF 常使用定制单元或手工布局而非让 P&R 自由放置。设计方法论：先通过 MTBF 公式计算最少级数，再加一级作为安全裕量。

### 适用范围

亚稳态影响贯穿数字设计：异步复位释放命中恢复/移除时间窗口——复位同步器的根本动因；跨时钟域边沿检测——"valid before data"错误的物理根源；异步握手协议——REQ/ACK 本质是单比特 CDC；芯片间互联——片外信号边沿速率通常慢于片内，更宽过渡时间使亚稳态触发概率更高，I/O 输入同步器比内部 CDC 更保守。

## 关键要点

- 亚稳态是双稳态元件的物理特性：输入在采样窗口内变化时，输出进入缓慢指数衰减的中间状态，解析时间无界
- $MTBF = e^{t_{res}/\tau} / (f_{clk} \cdot f_{data} \cdot T_0)$：$t_{res}$ 在指数项中，是最关键的设计参数——增加一级同步器可指数级提升可靠性
- $\tau$（再生时间常数）约 1-5 ps，由 $g_m$ 和节点电容决定——FinFET 因更高 $g_m$ 使 $\tau$ 更小，可靠性更好
- $T_0$（采样窗口参数）与建立-保持窗口宽度相关，典型 $10^{-8}$ 至 $10^{-10}$ 秒
- 典型 GHz 级设计中 2-FF 同步器的 MTBF 远超芯片寿命，足够安全；>5-10 GHz 或汽车 ASIL-D 需 3+ 级
- 同步器级间禁止任何组合逻辑，各级触发器需物理紧密放置、同一 VT 类别和驱动强度
- 亚稳态不是 Bug——它是物理规律，设计者的任务是确保其发生概率低到可接受的程度

## 与其他概念的关系

- [[cross-domain/concepts/clock-domain-crossing|跨时钟域设计（CDC）]] — CDC 全部同步器方案（2-FF、Gray FIFO、Handshake）以亚稳态理论和 MTBF 公式为物理基础
- [[cross-domain/concepts/reset-methodology|复位策略（Reset Methodology）]] — 异步复位释放触发的亚稳态是复位同步器设计的根本动因
- [[concepts/cmos-fundamentals|CMOS 基础]] — 双稳态电路的晶体管级实现（交叉耦合反相器）和再生过程的 $g_m/C$ 小信号模型
- [[concepts/semiconductor-basics|半导体基础]] — $\tau$ 的物理来源：晶体管跨导（载流子迁移率）和节点电容的工艺依赖性
