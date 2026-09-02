---
type: moc
aliases:
  - ASIC Flow MOC_ASIC 实现流程总览
  - ASIC Flow Map of Content
tags:
  - asic
  - asic-flow
  - moc
source_spec: "Synopsys ICC/DC/PrimeTime Reference, Cadence Innovus/Genus Reference, Weste & Harris CMOS VLSI Design"
queries: 1
---
# ASIC 实现流程总览

ASIC 实现流程（Application-Specific Integrated Circuit Flow）是将 RTL 设计转化为可用于制造的物理版图（GDSII）的完整工程流程。这一流程从前端综合开始，经历物理设计（布局布线、时钟树、电源网络），最终以签核（Signoff）结束，涵盖时序、功耗、可测试性和物理验证等多个维度的交叉任务。整个流程通常在业界标准 EDA 工具的驱动下完成，包括 Synopsys 的 Design Compiler / IC Compiler II / PrimeTime 生态和 Cadence 的 Genus / Innovus / Tempus 生态。

本 MOC 汇总 ASIC 实现流程的核心概念，按流程推进顺序组织：综合（Synthesis）将 RTL 转为门级网表，DFT（Design for Testability）插入测试结构，物理设计阶段包括布局布线（P&R）和时钟树综合（CTS），最后是功耗分析、物理验证和签核。每一阶段都有严格的质量关卡，前一阶段的输出是后一阶段的输入，任何环节的问题都可能导致流片失败。

![Asic Flow Overview](assets/asic-flow-overview.svg)

## 核心概念索引

### 前端实现

- [[asic-flow/concepts/逻辑综合|逻辑综合（Synthesis）]] — RTL 精化、技术映射、SDC 约束、Design Compiler / Genus 流程
- [[asic-flow/concepts/RTL与网表|RTL 与网表]] — 作用/联系/区别、网表五维分类（GTECH/扁平层次/扫描/2D3D/格式）、生命周期
- [[asic-flow/concepts/后端支持BES|后端支持（BES）]] — 中端岗位：综合/DFT/LEC/STA/功耗分析/网表交付，面向后端的一站式支持
- [[asic-flow/concepts/静态时序分析|静态时序分析（STA）]] — 建立/保持检查、时序路径分类、多角多模分析、PrimeTime / Tempus
- [[asic-flow/concepts/可测试性设计|可测试性设计（DFT）]] — 扫描链、ATPG、压缩架构、MBIST/LBIST、JTAG/IEEE 1149.1、端到端八步流程
- [[asic-flow/concepts/逻辑等价性检查|逻辑等价性检查（LEC）]] — RTL 与网表的等价性证明：综合/DFT/ECO 每步网表变换的守门员

### 物理实现

- [[asic-flow/concepts/时钟树综合|时钟树综合（CTS）]] — 时钟树拓扑、偏斜最小化、有用偏斜、时钟网格、时钟功耗
- [[asic-flow/concepts/2D与3D网表|2D 网表与 3D 网表]] — 单 Die vs 3D-IC 网表：Die 归属、TSV 垂直互连、跨 Die 时序/热分析
- [[asic-flow/concepts/布局布线|布局布线（P&R）]] — 布图规划、全局/详细布局、全局/详细布线、ECO、Innovus/ICC2
- [[asic-flow/concepts/功耗分析|功耗分析（Power Analysis）]] — 动态/静态功耗、时钟门控、电源门控、Multi-Vth、DVFS、IR Drop

### 后端签核

- [[asic-flow/concepts/签核|签核（Signoff）]] — 时序签核、IR Drop、电迁移、形式等价检查、LEC
- [[asic-flow/concepts/物理验证|物理验证（Physical Verification）]] — DRC、LVS、ERC、天线规则、密度检查、DFM

## 相关领域

- [[rtl-design/RTL设计|RTL 设计（RTL Design）]] — RTL 代码是综合的输入，编码风格直接影响实现质量
- [[verification/功能验证|功能验证（Verification）]] — 验证确保 RTL 功能正确，是流片前的最后防线
- [[cross-domain/concepts/时序收敛|跨领域 — 时序收敛（Timing Closure）]] — 从综合到签核的跨阶段时序优化方法论
- [[cross-domain/concepts/低功耗设计|跨领域 — 低功耗设计（Low Power Design）]] — UPF/CPF 驱动的跨流程低功耗技术

## 推荐阅读顺序

对于刚接触 ASIC 实现流程的学习者，建议按以下顺序阅读：

1. 理解综合如何将 RTL 转为门级网表：[[asic-flow/concepts/逻辑综合|逻辑综合]]
2. 掌握时序分析的核心方法：[[asic-flow/concepts/静态时序分析|静态时序分析]]
3. 了解芯片可测试性的设计思想：[[asic-flow/concepts/可测试性设计|可测试性设计]]
4. 进入物理设计阶段：[[asic-flow/concepts/布局布线|布局布线]] → [[asic-flow/concepts/时钟树综合|时钟树综合]]
5. 分析功耗与签核：[[asic-flow/concepts/功耗分析|功耗分析]] → [[asic-flow/concepts/签核|签核]]
6. 进行最终的物理验证：[[asic-flow/concepts/物理验证|物理验证]]

## 高频查询（易忘知识点排名）

| 排名 | 概念 | 查询次数 | 最后查询 |
|:---|:---|:---|:---|
| 1 | [[asic-flow/concepts/静态时序分析\|静态时序分析（STA / Critical Path / Skew & Jitter / Multi-Cycle / False Path / Fmax / Clock Uncertainty / OCV / Max Transition / Setup & Hold Check / 前后端违例修复 / 动态时序分析辨析）]] | 14 | 2026-08-31 |
| 2 | [[asic-flow/concepts/功耗分析\|功耗分析（Power Analysis / VCD / SAIF / PTPX / What-If / FSDB转VCD / VDDC-VDDP分域 / UPF低功耗仿真 / 三分量来源与静态动态 / 组合与时序功耗 / SPEF与网表关系）]] | 10 | 2026-09-02 |
| 3 | [[asic-flow/concepts/逻辑综合\|逻辑综合（面积速度权衡 / 资源共享 / Retiming / 综合流程）]] | 3 | 2026-07-23 |
| 4 | [[asic-flow/concepts/可测试性设计\|可测试性设计（DFT：端到端八步流程 / 扫描替换 / ATPG / MBIST March C-）]] | 3 | 2026-08-26 |
| 5 | [[asic-flow/concepts/布局布线\|布局布线（Floorplan / Placement / CTS / Routing / 时序影响）]] | 2 | 2026-07-23 |
| 6 | [[asic-flow/concepts/RTL与网表\|RTL 与网表（作用联系区别 / 网表五维分类 / 开关级 / EDIF）]] | 2 | 2026-08-26 |
| 7 | [[asic-flow/concepts/时钟树综合\|时钟树综合（CTS / Skew vs Latency / CTS前后时序差异）]] | 1 | 2026-07-23 |
| 8 | [[asic-flow/concepts/后端支持BES\|后端支持（BES：综合/DFT/LEC/STA/网表交付/ECO）]] | 1 | 2026-08-26 |
| 9 | [[asic-flow/concepts/2D与3D网表\|2D 网表与 3D 网表（Die归属 / TSV / 跨Die时序热分析）]] | 1 | 2026-08-26 |
