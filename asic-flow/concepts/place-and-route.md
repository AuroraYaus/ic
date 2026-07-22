---
type: concept
aliases:
  - P&R
  - Place and Route
  - 布局布线
  - Physical Design
tags:
  - asic
  - asic-flow
  - pnr
  - physical-design
source_spec: "Cadence Innovus User Guide, Synopsys ICC2 User Guide, Kahng/Lienig/Markov/Hu VLSI Physical Design Ch.3-5"
---

# 布局布线（Place and Route）

布局布线（Place and Route, P&R）是 ASIC 物理设计的核心阶段，将门级网表中数百万乃至数十亿个标准单元和宏模块精确映射到芯片版图（Layout/GDSII）的物理坐标上，并完成所有逻辑连接的金属走线。P&R 的质量直接决定了芯片的最终频率、功耗和面积——一个好的布局可以使关键路径缩短 30%-50%，差的布局则导致布线拥塞无法修复。主流 EDA 工具为 Cadence Innovus（现称 Innovus Implementation System）和 Synopsys IC Compiler II（ICC2），两者均采用层次化、并行化的设计流程，可在数小时内完成数十亿晶体管级 SoC 的物理实现。

## 原理

### 布图规划（Floorplanning）

布图规划是 P&R 的起点和最重要的决策点——布图规划阶段的错误在后续步骤中几乎无法修复。核心任务包括：定义芯片边界（Die Area）和利用率（Utilization Rate, 通常 60%-75%，预留布线空间）；放置 I/O Pad 单元（考虑封装基板走线和 ESD 保护结构）；创建电源/地网格（Power/Ground Grid）——典型结构为高层厚金属（Top Metal Layers）的交替 VDD/VSS 金属条带，通过通孔堆叠（Via Stack）连接至标准单元行（Standard Cell Row）供电轨，需满足 IR 压降（IR Drop）预算（通常 < 5%-10% VDD）。

宏模块放置（Macro Placement）是最关键的决策——大型 IP 模块（SRAM、PLL、SerDes、模拟 IP）通常沿芯片边缘或角落放置，以形成连续的标准单元区域（Core Area）。宏模块放置需考虑：引脚方向（Pin Orientation）朝向标准单元区域以减少绕线、相邻宏模块之间的通道布线空间（Channel Routing）、以及热梯度分布（高功耗宏模块不聚集）。宏模块位置不当导致的布线拥塞（Routing Congestion）表现为局部金属层利用率超过 90%，在后续详细布线阶段无法收敛——拥塞驱动的布图规划（Congestion-Driven Floorplanning）使用全局布线估算来指导宏模块调整是先进流程的标准实践。

### 布局（Placement）

布局分为三个子阶段。**全局布局（Global Placement）**：使用解析方法（Analytical Placement）——将布局问题建模为带约束的连续优化问题。基于二次线长（Quadratic Wirelength）的目标函数将所有单元当作无面积的质点，通过解大型稀疏线性方程组获得最小线长解，再通过逐步增加单元扩散力（Spreading Force）来消除重叠，直至所有单元分布在芯片区域内。密度惩罚项（Density Penalty）逐步增大以保证单元分布均匀。现代工具也使用非线性非凸优化引擎（ePlace/RePlAce 算法）将线长和密度约束统一在非线性目标函数中求解。

**合法化（Legalization）**：全局布局产生的位置未必对齐到标准单元行（Row）的合法放置点（Placement Site），且存在单元重叠。合法化阶段在最小位移的约束下将单元逐个对齐到合法位置，消除所有重叠。Tetris 风格的扫描线算法逐行扫描处理剩余重叠，但过度扰动会严重恶化线长和时序——合法化质量直接影响后续步骤的收敛性。

**详细布局（Detailed Placement）**：在合法化结果上进行局部优化——交换相邻单元以减小线长、优化引脚接入点以减少绕线拥塞、插入 filler cell 和 well tap cell 以满足设计规则（N-well 间距、栓锁预防）。

### CTS 插入点

布局完成后、详细布线之前插入 CTS。标准流程顺序为：布图规划 -> 电源网格 -> 全局布局 -> 合法化 -> **CTS 插入** -> 时钟走线 -> 详细布线。这一顺序确保 CTS 工作时标准单元位置已经稳定（合法化后），从而能基于实际物理位置计算各叶节点的负载电容和 RC 延迟——如果 CTS 提前到布局之前，单元位置变化会使时钟树优化失效。

### 布线（Routing）

**全局布线（Global Routing）**：将芯片划分为全局布线单元（Global Routing Cell, GRC），在 GRC 级别规划各线网的大致走线路径——决定走线进入和离开每个 GRC 的方向。该阶段估算每层金属的走线需求和容量，检测拥塞热区。全局布线使用网格图（Grid Graph）模型，采用迷宫算法（Maze Routing / Lee's Algorithm）或 A* 搜索求解最短路径，并使用**拆线重布（Rip-up and Reroute）**策略处理拥塞——先完成所有线网初始布线，再逐个拆掉拥塞 GRC 中的线网用更长但非拥塞的路径重新走线，迭代至拥塞消除。

**轨道分配（Track Assignment）**：将全局布线的 GRC 级别路径映射到具体金属轨道（Routing Track）上——每条轨道对应版图中一条真实的金属线位置。轨道分配的目标是在不违反设计规则的前提下均匀分布金属线，减少相邻线之间的耦合电容串扰。

**详细布线（Detailed Routing）**：最终的精确定线——处理通孔（Via）插入、线端扩展（Wire Extension）、设计规则违反修复。使用 Maze/A* 路由算法逐段确定走线，处理同一层内的线端间距（End-of-Line Spacing）、最小面积、通孔包围等 DRC 规则。详细布线是计算密集型操作，通常采用并行分区策略将芯片分为独立子区域并行处理。

### ECO 流程

工程变更指令（Engineering Change Order, ECO）是在设计后期对网表的局部修改——修复时序违例、逻辑错误或满足新的规格要求——而不重新运行完整的 P&R 流程。ECO 流程在已有版图上利用预留单元（Spare Cell）或在版图空余位置插入少量新门，通过最小化的布局和走线扰动实现修改。ECO 的挑战在于在极度拥挤的版图中找到空间插入新单元而不引起大规模时序退化——基于签核时序结果驱动的 ECO 需要 STA 和 P&R 工具的紧密交互。

## 关键要点

- 布图规划的宏模块放置决策是最关键且不可逆的——宏模块位置不当导致的拥塞在后续阶段无法修复，Congestion-Driven Floorplanning 是标准实践
- 利用率（Utilization）预留 25%-40% 空白空间用于时钟树、缓冲器插入和布线——过高利用率导致不可收敛的拥塞，过低浪费面积和增加线长
- 全局布局使用解析方法（Analytical Placement, 二次线长+密度惩罚），将离散布局转为连续优化并解出全局最优，再合法化到离散放置点
- CTS 插入时机在标准单元合法化之后、详细布线之前——CTS 需要准确的单元位置来计算 RC 延迟
- 拆线重布（Rip-up and Reroute）是解决布线拥塞的经典策略，逐次迭代至拥塞消除——但可能过度拉长关键路径线长
- 详细布线使用 Maze/A* 算法逐段处理 DRC——是计算最密集的阶段，通常使用并行分区处理
- ECO 流程依赖预留单元（Spare Cell）实现局部网表修改，避免了完整重跑流程的数天周转时间——但受限于版图剩余空间
- Innovus 和 ICC2 均支持从 RTL 到 GDSII 的全流程，核心差异在于优化引擎、时序模型的集成度和多 CPU 扩展能力

## 与其他概念的关系

- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — 综合输出的门级网表和 SDC 约束是 P&R 的输入，物理综合在综合阶段引入布局信息以减少综合-P&R 时序鸿沟
- [[asic-flow/concepts/clock-tree|时钟树综合（CTS）]] — CTS 是 P&R 流程中的子阶段，位于全局布局和详细布线之间，P&R 工具集成了 CTS 引擎
- [[asic-flow/concepts/static-timing-analysis|静态时序分析（STA）]] — STA 驱动 P&R 的时序优化——每次布局或布线迭代后运行 STA 评估，违例驱动 ECO 修复
- [[asic-flow/concepts/signoff|签核（Signoff）]] — P&R 输出最终版图后，Signoff STA/DRC/LVS 验证决定是否可投片——P&R 的目标是满足所有签核指标
