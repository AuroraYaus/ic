---
type: concept
aliases:
  - CMOS Fundamentals_CMOS基础
  - CMOS Fundamentals
tags:
  - asic
  - basics
  - cmos
  - transistor
source_spec: "Weste & Harris, CMOS VLSI Design; Rabaey, Digital Integrated Circuits"
---
# CMOS Fundamentals — CMOS 基础

互补金属氧化物半导体（Complementary Metal-Oxide-Semiconductor, CMOS）是当代数字集成电路的主流工艺基础，几乎所有的数字芯片——从微处理器到存储器——都基于 CMOS 工艺制造。

## 原理

### CMOS 基本结构

CMOS 技术的核心是使用一对互补的晶体管——NMOS 和 PMOS——来构建逻辑门。NMOS 的沟道由电子导电，在栅极（Gate）电压高于源极（Source）一个阈值时导通，善于传递低电平（强 0）；PMOS 的沟道由空穴导电，在栅极电压低于源极一个阈值时导通，善于传递高电平（强 1）。两者互补工作，使得 CMOS 电路在任何稳态下都只有极小的漏电流流过——理想情况下静态功耗为零。

### 静态 CMOS 逻辑门

一个标准的 CMOS 反相器（Inverter）由一只 NMOS（作为下拉网络，Pull-Down Network, PDN）和一只 PMOS（作为上拉网络，Pull-Up Network, PUN）串联组成，栅极相连作为输入，漏极相连作为输出。当输入为高电平时，NMOS 导通、PMOS 截止，输出被 PDN 拉低到地（GND）；当输入为低电平时，PMOS 导通、NMOS 截止，输出被 PUN 拉高到电源电压（VDD）。

复杂 CMOS 逻辑门——NAND、NOR、AOI（And-Or-Invert）、OAI（Or-And-Invert）——通过扩展 PDN 和 PUN 的结构实现。设计规则遵循对偶原理（Duality Principle）：PDN 中 NMOS 的串联对应 PUN 中 PMOS 的并联，反之亦然。这一对偶性是 CMOS 静态逻辑设计的核心规律，确保了在任何输入组合下都不会出现从 VDD 到 GND 的直流通路。

### 功耗与性能

CMOS 电路的功耗分为三部分：**动态功耗（Dynamic Power）** 由信号跳变时负载电容的充放电产生，计算为 P_dynamic = α · C · V² · f，其中 α 是活动因子（Activity Factor），C 是负载电容，V 是电源电压，f 是时钟频率；**短路功耗（Short-Circuit Power）** 由输入信号翻转时 PMOS 和 NMOS 短暂同时导通产生；**静态功耗（Static Power / Leakage）** 由亚阈值漏电、栅极隧道电流和反向偏置 PN 结漏电组成，在先进工艺中已成为主导因素。

### 工艺缩放

工艺节点从微米级（μm）到深亚微米（DSM, Deep Sub-Micron）再到纳米级（7nm, 5nm, 3nm）。短沟道效应（Short-Channel Effects, SCE）——包括漏致势垒降低（DIBL）、速度饱和、热载流子效应——使得传统平面 CMOS 在 28nm 以下面临严重挑战。FinFET（鳍式场效应晶体管）和 GAA（Gate-All-Around）等 3D 晶体管结构通过将沟道从平面转为立体，大幅改善了栅极对沟道的静电控制。

### 功耗构成的深层分析

动态功耗 $P_{dyn} = \alpha \cdot C \cdot V_{DD}^2 \cdot f$ 的核心启示：$V_{DD}$ 以平方因子影响功耗，因此降低电源电压是最有效的功耗优化手段。每一代工艺节点都将标称 $V_{DD}$ 降低——从 180nm 的 1.8V 一路降至 5nm 的约 0.7V。但电压裕量的缩减使得噪声容限恶化，需要更精确的信号完整性分析。

静态功耗的三个主要漏电路径：
- **亚阈值漏电（Subthreshold Leakage）**：$V_{GS} < V_{th}$ 时的弱反型电流，按 $e^{-V_{th}/n\cdot U_T}$ 指数递减，室温下 $U_T = kT/q \approx 26\text{ mV}$。高 $V_{th}$ 器件漏电低但速度慢，低 $V_{th}$ 器件速度快但漏电高——Multi-Vth 库的核心物理权衡。
- **栅极漏电（Gate Leakage）**：载流子通过极薄栅氧化层的量子隧穿，$SiO_2$ 在 65nm 以下隧穿电流剧增，直接驱动 High-K 金属栅（HKMG）工艺的引入。
- **结漏电（Junction Leakage）**：反向偏置 PN 结的微小电流，与结面积和掺杂浓度相关。

先进工艺中漏电功耗可占芯片总功耗的 40-50%，多阈值电压（Multi-Vth）和电源门控（Power Gating）是应对策略的核心。

### 器件电容与扇出效应

逻辑门的负载主要来自三个电容成分：栅极电容 $C_g$（下一级输入管的栅氧化层电容，决定开关速度的核心分量）、扩散电容 $C_d$（源漏扩散区的结电容，与晶体管尺寸成正比）、互连线电容 $C_w$（金属走线的对地和耦合电容，先进工艺中成为主导）。扇出（Fan-Out）每增加 1，总负载电容近似增加 $C_g + C_w$，门延迟线性增长。在高速路径中，扇出通常限制在 4 以内（Logical Effort 理论的最优化比值）。对于扇出过大的关键路径，插入缓冲器（Buffer）——由两个反相器串联——将大负载分段驱动是标准做法。

### 延迟建模：Logical Effort

CMOS 门的传播延迟 $d$ 可分解为三个因子的乘积：

$$d = g \cdot h + p$$

其中 **逻辑努力（Logical Effort, $g$）** 是该门相对于反相器驱动给定输出电流的能力——反相器 $g = 1$，2 输入 NAND 约为 $4/3$，2 输入 NOR 约为 $5/3$（因 PMOS 迁移率低，NOR 门的并联 PMOS 面积大、$g$ 更高）。**电气努力（Electrical Effort, $h = C_{out}/C_{in}$）** 是输出负载与输入电容之比，即扇出。**寄生延迟（Parasitic Delay, $p$）** 是门驱动自身输出扩散电容所需的时间——反相器 $p \approx 1$，多输入门更高。

Logical Effort 理论的设计启示：最小路径延迟发生在各门承担相等 **级努力（Stage Effort, $f = g \cdot h$）** 时。对于无分支路径，最佳 $f \approx 3.6-4$，解释了为何扇出 4 是反相器链的最优选择。对于有分支的复杂路径，引入分支努力（Branching Effort, $b$）修正：总路径努力 $F = G \cdot B \cdot H$，最佳级努力 $\hat{f} = F^{1/N}$，反相器链级数 $N = \log_{\hat{f}} F$。这一理论统一了门尺寸选择和缓冲器插入的方法论。

### 传输门与动态逻辑

静态 CMOS 逻辑之外，两种补充结构在特定场景中使用：**传输门（Transmission Gate）** 由一只 NMOS 和一只 PMOS 并联构成——NMOS 导通强 0 弱 1，PMOS 导通强 1 弱 0，两者互补使传输门在整个信号摆幅范围内（$0$ 到 $V_{DD}$）都能有效传递信号。传输门是选择器（MUX）、锁存器（Latch）和触发器（Flip-Flop）的晶体管级基础。**动态逻辑（Dynamic Logic）** 利用预充电-求值（Precharge-Evaluate）两相操作：预充阶段将输出节点预充电到 $V_{DD}$，求值阶段通过 PDN 有条件放电。动态逻辑比静态 CMOS 更快更紧凑——仅需 N 个 NMOS 实现 N 输入逻辑（无 PMOS PUN），但存在电荷泄漏（Charge Leakage）、电荷共享（Charge Sharing）和噪声敏感性问题，需要在设计中通过 Keeper 晶体管和时钟频率下界等手段加以约束。

### 锁存器与触发器的 CMOS 实现

CMOS 锁存器（Latch）——电平敏感存储元件——可由传输门和交叉耦合反相器构成：时钟高电平时输入传输到输出（透明阶段），时钟低电平时反馈回路维持输出（保持阶段）。主从触发器（Master-Slave Flip-Flop）将两个反相时钟的锁存器串联：主锁存器在时钟低电平时透明，从锁存器在时钟高电平时透明，整体实现上升沿触发。现代标准单元库中的 D 触发器采用优化的传输门结构，其建立时间（Setup Time）、保持时间（Hold Time）和 C-to-Q 延迟（Clock-to-Q Delay）是时序分析的关键参数。

### 工艺角与片上变异

工艺角（Process Corner）是制造变异条件下晶体管性能极端组合的工程抽象。最常用的五个角：

- **TT（Typical-Typical）**：NMOS 和 PMOS 均为典型参数——名义时序和功耗分析的基准
- **SS（Slow-Slow）**：两者均慢——高 $V_{th}$、低 $I_{on}$，通常对应最长路径延迟（Setup Worst Case），用于建立时间检查
- **FF（Fast-Fast）**：两者均快——低 $V_{th}$、高 $I_{on}$，通常对应最短路径延迟（Hold Worst Case），用于保持时间检查
- **SF（Slow-Fast）**：NMOS 慢而 PMOS 快——PMOS 强驱动导致上升沿快、下降沿慢，影响时钟占空比和脉冲宽度
- **FS（Fast-Slow）**：NMOS 快而 PMOS 慢——下降沿快、上升沿慢，与 SF 互补

在先进 FinFET 工艺中，鳍高变异引入的随机涨落使得全局 Corner 不足以覆盖局部变异——片上变异（On-Chip Variation, OCV）通过降额因子（Derating Factor）为每个时序弧施加额外的悲观裕量。先进 OCV（AOCV）和参数化片上变异（POCV）使用基于深度和距离的降额模型，替代了统一降额的粗暴做法，在覆盖变异的同减少了过度悲观。

## 关键要点

- CMOS 静态功耗极低，动态功耗与开关频率成正比（$P = \alpha \cdot C \cdot V^2 \cdot f$），这是功耗优化的理论基础
- 阈值电压（Threshold Voltage, Vth）决定了晶体管的开关点，Multi-Vth 技术是低功耗设计的核心手段——典型库提供 HVT（低速低漏电）、SVT（标准）、LVT（高速高漏电）三种选择
- 工艺节点持续缩小到 3nm 及以下，每一代带来约 30% 的面积缩小和 40% 的功耗降低
- 标准单元库（Standard Cell Library）提供预设计的 CMOS 门级电路，是 RTL-to-GDSII 流程的基础
- 噪声容限（Noise Margin）保证数字信号的抗干扰能力：$NM_H = V_{OH} - V_{IH}$，$NM_L = V_{IL} - V_{OL}$
- 反相器的电压传输特性（Voltage Transfer Characteristic, VTC）定义了 VIH、VIL、VOH、VOL 等关键参数，设计了逻辑阈值 $V_M \approx V_{DD}/2$ 以获得对称噪声容限
- 扇出（Fan-Out）增大导致负载电容增加，直接影响门延迟和动态功耗——高速路径中扇出通常限制在 4 以内
- FinFET 工艺中，驱动能力通过鳍的数量（而非沟道宽度）来调整，改变了传统的尺寸缩放方式
- 亚阈值斜摆（Subthreshold Swing, SS）的理论极限为 60 mV/dec（室温），实际器件约 70-100 mV/dec——这是 MOSFET 开关陡峭度的物理极限
- 电源电压从 180nm 的 1.8V 降至 3nm 的约 0.6V，电压裕量收窄使 IR-Drop 和地弹对时序的影响更加显著

## 与其他概念的关系

- [[concepts/Semiconductor Basics_半导体基础|半导体基础]] — CMOS 工艺的物理基础：MOSFET 的能带模型、载流子输运、PN 结和短沟道效应决定了晶体管在先进工艺中的行为边界，所有数字设计权衡最终都受这些物理规律约束
- [[asic-flow/concepts/Synthesis_逻辑综合|逻辑综合（Synthesis）]] — 综合工具根据约束（时序、功耗、面积）从标准单元库中选择 CMOS 门并映射 RTL 到门级网表，Logical Effort 理论指导了单元驱动能力的选择策略
- [[asic-flow/concepts/Power Analysis_功耗分析|功耗分析（Power Analysis）]] — 基于 $P = \alpha C V^2 f$ 的动态功耗分析、亚阈值漏电和栅极漏电的静态功耗建模，工程上使用 SAIF/VCD 文件进行 activity-based 功耗估算
- [[concepts/Number Systems_数制|数字的数制表示]] — CMOS 电路以二进制比特为操作对象，所有算术逻辑单元（ALU）的底层实现——加法器、乘法器、移位器——均基于 CMOS 逻辑门
