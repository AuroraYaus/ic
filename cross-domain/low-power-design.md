---
type: concept
aliases:
  - 低功耗设计
  - UPF
  - Power Intent
  - Power Gating
  - Clock Gating
  - Multi-Vth
  - DVFS
tags:
  - asic
  - cross-domain
  - low-power
  - upf
  - physical-design
  - rtl-design
source_spec: "IEEE 1801 (UPF); Keating et al., Low Power Methodology Manual (LPMM); Synopsys Low Power Flow Guide"
---

# 低功耗设计（Low-Power Design）

低功耗设计（Low-Power Design）是现代数字IC设计中最关键的横切关注点之一，它横跨架构设计、RTL 编码、逻辑综合、物理实现直至 Signoff 的全流程。功耗不仅是移动和物联网设备中电池寿命的决定因素，在数据中心和高性能计算领域也直接制约着散热能力（Thermal Design Power, TDP）和封装成本。低功耗设计的核心是在性能（Performance）、面积（Area）和功耗（Power）——即 PPA 三角——之间找到最优平衡点。

## 原理

### 功耗的分类与根源

数字IC的功耗分为静态功耗和动态功耗两大类。动态功耗（Dynamic Power）由信号跳变引起：P_dynamic = α · C · V² · f，其中 α 为活动因子，C 为负载电容，V 为电源电压，f 为时钟频率。静态功耗（Leakage Power / Static Power）在先进工艺（28nm 以下）中占比不断上升，主要来源包括：亚阈值漏电（Subthreshold Leakage）——晶体管在 Vgs < Vth 时仍有微弱电流；栅极隧道漏电（Gate Tunneling Leakage）——栅氧化层减薄到原子尺度后量子隧穿效应显著；以及反向偏置结漏电（Reverse-Biased Junction Leakage）。先进工艺中静态功耗已可与动态功耗匹敌，甚至在某些低活动率场景下成为主导——这也是 Power Gating 和 Multi-Vth 等技术变得如此重要的原因。

### UPF与功耗意图

统一功耗格式（Unified Power Format, UPF, IEEE 1801）是描述芯片功耗意图（Power Intent）的行业标准。UPF 定义的关键概念包括：**功耗域（Power Domain）**——可以独立开关或调节电压的逻辑区域；**供电网络（Supply Net / Supply Set）**——包含主电源（Primary Power）、保持电源（Retention Power）等；**供电端口（Supply Port）**——功耗域的电源连接点；**隔离单元（Isolation Cell）**——在关闭的功耗域输出端插入，防止未知值（X）传播到常开域；**电平转换器（Level Shifter）**——在不同电压的功耗域之间转换信号电平；**保持寄存器（Retention Register）**——在掉电前保存状态、上电后恢复的专用寄存器；**电源开关（Power Switch）**——控制功耗域通断的晶体管网络（Header Switch 用 PMOS 接 VDD，Footer Switch 用 NMOS 接 GND）。UPF 文件贯穿综合、仿真、形式验证、物理实现全流程，确保功耗意图的一致性和正确性。

### 架构与RTL级功耗优化

**时钟门控（Clock Gating）** 是 RTL 级最有效、应用最广泛的低功耗技术。通过在寄存器组的时钟路径上插入与门（AND Gate）或锁存器+与门（Latch-Based Clock Gating Cell），当时钟使能信号（Clock Enable）为低时阻止时钟翻转，消除寄存器组内无谓的时钟树功耗和数据路径翻转功耗。RTL 风格直接影响时钟门控插入效率：条件赋值导致寄存器保持原值（`if (en) q <= d`）会被综合工具自动插入时钟门控；而 `q <= en ? d : 0` 这种风格则无法门控。操作数隔离（Operand Isolation）是算术数据路径的低功耗技术——当计算单元的输出在当前周期不被使用时，通过门控阻止其输入翻转来抑制动态功耗。

### 物理级功耗优化

**多阈值电压（Multi-Vth）** 技术利用不同阈值电压晶体管的特性差异：高阈值电压（HVT, High Vth）单元漏电低但速度慢，低阈值电压（LVT, Low Vth）单元速度快但漏电高，标准阈值电压（SVT, Standard Vth）居中。综合工具以时序为约束，优先使用 HVT，仅在关键路径上使用 LVT，实现速度与漏电的平衡。**电源门控（Power Gating）** 通过电源开关晶体管在休眠期间彻底切断某个功耗域的供电，可将该域的静态功耗降至近乎为零——代价是唤醒延迟和浪涌电流（Inrush Current）管理。**动态电压频率调节（Dynamic Voltage and Frequency Scaling, DVFS）** 根据当前工作负载实时调整电压和频率——由于动态功耗与 V²f 成正比，即使适度的电压降低也能带来显著的功耗节省。**自适应电压调节（Adaptive Voltage Scaling, AVS）** 通过片上性能监控器（Performance Monitor）构成闭环：根据硅片的实际速度反馈调整电压，消除设计裕量。**体偏置（Body Bias）** 通过调节衬底电压改变 Vth：正向体偏置（FBB, Forward Body Bias）降低 Vth 提速，反向体偏置（RBB, Reverse Body Bias）提高 Vth 降漏电——在 FDSOI 工艺中尤为有效。

### 动态功耗与漏电功耗的权衡

动态功耗优化和漏电功耗优化常常相互冲突：例如，使用 LVT 单元加速关键路径会增加漏电；过度使用电源门控虽然降低漏电，但唤醒过程消耗额外的动态能量。低功耗设计的艺术在于理解应用场景的活动率分布（Activity Profile）——是持续高活动率（如视频解码、HPC 计算）还是大部分时间空闲（如 IoT 传感器、可穿戴设备）——从而选择合适的优化策略组合。现代 EDA 工具支持多目标优化（Multi-Objective Optimization），以 PPA 加权评分函数指导自动单元替换和 P&R 优化。

## 关键要点

- P_dynamic = α · C · V² · f——电压（V）对动态功耗的影响是平方关系，是最有力的功耗优化杠杆
- UPF（IEEE 1801）是贯穿全流程的功耗意图描述标准，定义了功耗域、隔离、电平转换、保持和电源开关五大要素
- 时钟门控是 RTL 级最有效的低功耗手段，但需要编码风格配合——条件赋值（保持原值）才能被综合工具自动插入门控
- Multi-Vth 在 HVT（低速低漏电）和 LVT（高速高漏电）之间按需分配，是物理级 PPA 优化的核心技术
- 电源门控以唤醒延迟和浪涌电流为代价换取消灭静态功耗，需仔细设计电源开关（Ring/Grid/Stripe 布局）和唤醒序列
- DVFS 要求电压调节器和时钟生成器协同工作，AVS 进一步通过闭环反馈消除硅片间差异的裕量
- 保持寄存器（Retention Register）在掉电前保存关键状态，是电源门控能真正落地的关键——否则醒来就是一片空白
- FDSOI 工艺的体偏置技术可在运行时动态调节 Vth，提供额外的功耗优化维度

## 与其他概念的关系

- [[concepts/cmos-fundamentals|CMOS 基础]] — Vth、漏电机制（亚阈值/栅隧穿/结漏电）和电压-频率关系的物理基础
- [[concepts/semiconductor-basics|半导体基础]] — 掺杂浓度和沟道长度对 Vth 的影响，PVT 变异对功耗特征的作用
- [[cross-domain/timing-closure|时序收敛]] — 多电压域引入多 Corner/Mode 场景，Level Shifter 和 Isolation Cell 增加时序路径复杂度
- [[cross-domain/clock-domain-crossing|跨时钟域设计]] — DVFS 产生多时钟域，CDC 和低功耗设计在多频场景下高度耦合
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — RTL 级（无矢量/有矢量）和门级功耗分析的方法论，Signoff 功耗验证
- [[asic-flow/concepts/power-grid|电源网络设计（Power Grid）]] — PDN 设计、IR-drop 分析与低功耗策略（尤其是电源门控）的物理实现耦合
