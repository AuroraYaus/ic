---
type: concept
aliases:
  - P&R
  - Place and Route
  - 布局布线
tags:
  - asic
  - asic-flow
  - pnr
  - physical-design
source_spec: "Cadence Innovus User Guide, Synopsys IC Compiler II User Guide, Weste & Harris CMOS VLSI Design Ch.15"
---

# 布局布线（Place and Route）

布局布线（Place and Route, P&R）是 ASIC 物理设计的核心阶段，将门级网表中的数百万乃至数十亿个标准单元和宏模块精确映射到芯片版图的物理坐标上，并完成所有逻辑连接的金属走线。P&R 的质量直接决定了芯片的最终频率、功耗和面积。主要 EDA 工具为 Cadence Innovus 和 Synopsys IC Compiler II。

## 原理

### 布图规划

布图规划（Floorplanning）是 P&R 的起点，决定芯片的宏观物理结构。核心任务包括：定义芯片边界（Die Area）、放置 I/O Pad 单元（沿芯片边缘）、创建电源/地网格（Power/Ground Grid）——典型结构为交替的 M1/M2 金属条带配合通孔堆叠（Via Stack）实现垂直供电，需预留 IR 压降（IR Drop）预算。宏模块（Memory、模拟 IP、硬核 IP）放置是最关键的决策——通常沿芯片边缘或角落放置以形成连续的标准单元区域，需考虑宏模块之间的通道布线空间和引脚可达性。宏模块位置不当导致的布线拥塞在后续阶段几乎不可修复。

### 布局三阶段

全局布局（Global Placement）采用二次优化或解析布局算法，以最小化总加权线长为目标，同时满足密度约束防止局部过度拥塞，输出粗糙单元坐标。合法化（Legalization）将单元对齐到行/站点网格（Row/Site Grid），消除重叠，满足最小间距约束——将连续坐标"量化"到离散放置站点上。详细布局（Detailed Placement）进行局部细化——交换相邻单元减少线长、消除局部拥塞热点。时钟树综合（CTS）的插入点位于详细布局之后、布线之前——此时标准单元位置已稳定，可以开始构建基于物理位置的时钟分配网络。

### 布线三阶段

全局布线（Global Routing）将芯片划分为全局布线单元网格（GRC），为每个线网分配通过的 GRC 路径，使各 GRC 内线网数量不超过布线通道容量——溢出时触发"撕断重布（Rip-Up and Reroute）"策略。轨道分配（Track Assignment）将每个线网分配到各金属层的具体布线轨道上。详细布线（Detail Routing）使用迷宫算法（Maze Router / A-star 搜索）在布线图上逐段完成实际连线，实时解决 DRC 违反。时钟和电源等特殊线网适用非默认规则（NDR）——加宽金属宽度和间距以保证信号完整性。详细布线是 NP 完全问题，启发式搜索和层分配策略的精心调节是可行性的关键。

### ECO 流程

工程变更命令（Engineering Change Order, ECO）以最小扰动方式修改已布局布线的设计。初始 P&R 时预插入备用单元（Spare Cells），后期通过仅修改金属层（Metal-Only ECO）的方式激活备用单元，大幅降低光罩改版成本。ECO 布线的核心原则是最小化对现有布线的扰动，通常仅限于受影响区域的局部重新布线。

## 关键要点

- P&R 流程：布图规划 -> 全局布局 -> 合法化 -> 详细布局 -> CTS -> 全局布线 -> 轨道分配 -> 详细布线 -> ECO
- 宏模块放置是布图规划中最关键的决策——位置不当导致布线拥塞不可修复，通常沿边缘分布以形成连续标准单元区
- 电源网格采用 M1/M2 交替条带 + Via Stack，须预留 IR Drop 预算——供电不足导致局部电压过低引发时序违例
- 合法化将全局布局的连续坐标量化到离散站点网格，消除重叠和间距违反
- 撕断重布（Rip-Up and Reroute）是解决全局布线拥塞的核心策略——拆除溢出 GRC 中部分线网尝试替代路径
- 非默认规则（NDR）为时钟/电源等关键线网提供加宽金属和加大间距——以布线资源换取信号完整性
- ECO 通过预插入备用单元实现仅金属层修改的设计变更——是降低光罩成本的成熟策略
- 主要 EDA 工具：Cadence Innovus（以 CCD/CTS 集成见长）和 Synopsys IC Compiler II（以融合式物理综合见长）

## 与其他概念的关系

- [[asic-flow/concepts/clock-tree|时钟树综合（CTS）]] — CTS 嵌入在详细布局和布线之间，使用已稳定的单元位置构建物理时钟树
- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — 综合输出的门级网表是 P&R 的直接输入，物理综合的目标是缩小两者时序鸿沟
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — P&R 输出带寄生参数的网表用于精确功耗分析，电源网格 IR Drop 直接影响功耗估算精度
- [[asic-flow/concepts/physical-verification|物理验证（Physical Verification）]] — P&R 输出的 GDSII 需通过 DRC/LVS 验证，任何违反需返回 P&R 做 ECO 修复
- [[asic-flow/concepts/signoff|签核（Signoff）]] — P&R 完成后的 GDSII 是各签核维度的对象，全部通过才能释放给晶圆厂
