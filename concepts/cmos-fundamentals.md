---
type: concept
aliases:
  - CMOS基础
  - CMOS Fundamentals
tags:
  - asic
  - basics
  - cmos
  - transistor
source_spec: "Weste & Harris, CMOS VLSI Design; Rabaey, Digital Integrated Circuits"
---

# CMOS 基础（CMOS Fundamentals）

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

## 关键要点

- CMOS 静态功耗极低，动态功耗与开关频率成正比（P = α · C · V² · f），这是功耗优化的理论基础
- 阈值电压（Threshold Voltage, Vth）决定了晶体管的开关点，Multi-Vth 技术是低功耗设计的核心手段
- 工艺节点持续缩小到 3nm 及以下，每一代带来约 30% 的面积缩小和 40% 的功耗降低
- 标准单元库（Standard Cell Library）提供预设计的 CMOS 门级电路，是 RTL-to-GDSII 流程的基础
- 噪声容限（Noise Margin）保证数字信号的抗干扰能力：NM_H = VOH - VIH, NM_L = VIL - VOL
- 反相器的电压传输特性（Voltage Transfer Characteristic, VTC）定义了 VIH、VIL、VOH、VOL 等关键参数
- 扇出（Fan-Out）增大导致负载电容增加，直接影响门延迟和动态功耗
- FinFET 工艺中，驱动能力通过鳍的数量（而非沟道宽度）来调整，改变了传统的尺寸缩放方式

## 与其他概念的关系

- [[concepts/semiconductor-basics|半导体基础]] — CMOS 工艺的物理基础：PN 结、MOSFET 的能带模型和载流子输运
- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — 综合工具将 RTL 映射到标准单元库中的 CMOS 门级网表
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — CMOS 动态/静态功耗的工程计算与优化策略
- [[concepts/number-systems|数字的数制表示]] — 数字逻辑的数学基础，CMOS 电路的操作对象
