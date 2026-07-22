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
---

# ASIC 实现流程（ASIC Flow）— 总览

ASIC 实现流程（Application-Specific Integrated Circuit Flow）是将 RTL 设计转化为可用于制造的物理版图（GDSII）的完整工程流程。这一流程从前端综合开始，经历物理设计（布局布线、时钟树、电源网络），最终以签核（Signoff）结束，涵盖时序、功耗、可测试性和物理验证等多个维度的交叉任务。整个流程通常在业界标准 EDA 工具的驱动下完成，包括 Synopsys 的 Design Compiler / IC Compiler II / PrimeTime 生态和 Cadence 的 Genus / Innovus / Tempus 生态。

本 MOC 汇总 ASIC 实现流程的核心概念，按流程推进顺序组织：综合（Synthesis）将 RTL 转为门级网表，DFT（Design for Testability）插入测试结构，物理设计阶段包括布局布线（P&R）和时钟树综合（CTS），最后是功耗分析、物理验证和签核。每一阶段都有严格的质量关卡，前一阶段的输出是后一阶段的输入，任何环节的问题都可能导致流片失败。

## 核心概念索引

### 前端实现

- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — RTL 精化、技术映射、SDC 约束、Design Compiler / Genus 流程
- [[asic-flow/concepts/static-timing-analysis|静态时序分析（STA）]] — 建立/保持检查、时序路径分类、多角多模分析、PrimeTime / Tempus
- [[asic-flow/concepts/dft|可测试性设计（DFT）]] — 扫描链、ATPG、压缩架构、MBIST/LBIST、JTAG/IEEE 1149.1

### 物理实现

- [[asic-flow/concepts/clock-tree|时钟树综合（CTS）]] — 时钟树拓扑、偏斜最小化、有用偏斜、时钟网格、时钟功耗
- [[asic-flow/concepts/place-and-route|布局布线（P&R）]] — 布图规划、全局/详细布局、全局/详细布线、ECO、Innovus/ICC2
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — 动态/静态功耗、时钟门控、电源门控、Multi-Vth、DVFS、IR Drop

### 后端签核

- [[asic-flow/concepts/signoff|签核（Signoff）]] — 时序签核、IR Drop、电迁移、形式等价检查、LEC
- [[asic-flow/concepts/physical-verification|物理验证（Physical Verification）]] — DRC、LVS、ERC、天线规则、密度检查、DFM

## 相关领域

- [[rtl-design/rtl-design_MOC|RTL 设计（RTL Design）]] — RTL 代码是综合的输入，编码风格直接影响实现质量
- [[verification/verification_MOC|功能验证（Verification）]] — 验证确保 RTL 功能正确，是流片前的最后防线
- [[cross-domain/concepts/timing-closure|跨领域 — 时序收敛（Timing Closure）]] — 从综合到签核的跨阶段时序优化方法论
- [[cross-domain/concepts/low-power-design|跨领域 — 低功耗设计（Low Power Design）]] — UPF/CPF 驱动的跨流程低功耗技术

## 推荐阅读顺序

对于刚接触 ASIC 实现流程的学习者，建议按以下顺序阅读：

1. 理解综合如何将 RTL 转为门级网表：[[asic-flow/concepts/synthesis|逻辑综合]]
2. 掌握时序分析的核心方法：[[asic-flow/concepts/static-timing-analysis|静态时序分析]]
3. 了解芯片可测试性的设计思想：[[asic-flow/concepts/dft|可测试性设计]]
4. 进入物理设计阶段：[[asic-flow/concepts/place-and-route|布局布线]] → [[asic-flow/concepts/clock-tree|时钟树综合]]
5. 分析功耗与签核：[[asic-flow/concepts/power-analysis|功耗分析]] → [[asic-flow/concepts/signoff|签核]]
6. 进行最终的物理验证：[[asic-flow/concepts/physical-verification|物理验证]]
