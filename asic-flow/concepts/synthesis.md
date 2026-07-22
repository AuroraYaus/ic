---
type: concept
aliases:
  - Synthesis_逻辑综合
  - 逻辑综合
tags:
  - asic
  - asic-flow
  - synthesis
  - front-end
source_spec: "Synopsys Design Compiler User Guide, Cadence Genus User Guide, Weste & Harris CMOS VLSI Design Ch.13"
---
# Synthesis — 逻辑综合

逻辑综合（Logic Synthesis）是 ASIC 实现流程的第一个关键阶段，其任务是将寄存器传输级（Register Transfer Level, RTL）的硬件描述代码自动转换为由标准单元库中的门级电路组成的网表（Gate-Level Netlist）。综合过程不是简单的翻译，而是在满足时序、面积和功耗约束的前提下，进行大量优化决策的智能搜索过程。

## 原理

### 三阶段综合流程

现代逻辑综合工具（如 Synopsys Design Compiler、Cadence Genus）的执行过程分为三个主要阶段。第一阶段是 RTL 精化（RTL Elaboration）：综合工具解析 Verilog/SystemVerilog 代码，推断出寄存器、组合逻辑、状态机和存储器等高层结构，生成与工艺无关的通用技术网表（Generic Technology Network, GTECH 或 Generic Netlist）。精化阶段会进行基本的算术优化（如乘法器重构、常数传播）和冗余逻辑消除。

第二阶段是工艺无关优化（Technology-Independent Optimization）：工具在布尔代数层面优化逻辑结构。主要手段包括公共子表达式提取（Common Sub-expression Elimination）、逻辑重构（Logic Restructuring）——利用布尔函数的等价变换减少逻辑级数。例如 `f = ab + ac` 可因式分解为 `f = a(b + c)`，将两级逻辑减少为一级与门加一级或门。此外还有资源共享（Resource Sharing）：互斥操作可以共用同一个运算单元以节省面积。这一阶段的优化不涉及具体工艺库信息，只关注逻辑表达式的简化。

第三阶段是技术映射（Technology Mapping）：工具将优化后的工艺无关网表映射到目标标准单元库的具体门电路上。映射过程使用动态规划或 DAG（Directed Acyclic Graph）覆盖算法，将逻辑树分解为子图并与库中的门单元进行匹配。关键技术包括：分解（Decomposition）将复杂逻辑函数分解为库中已有门的组合；扇出优化插入缓冲器以满足扇出限制；驱动强度选择根据负载电容选择适当的驱动能力。物理感知综合（Physical-Aware Synthesis）进一步引入了布局信息的反馈，在映射阶段就考虑互连线延迟和拥塞，避免了传统综合到布局迭代的反复。

### SDC 约束体系

综合的质量高度依赖于设计约束（Synopsys Design Constraints, SDC）文件的完整性和准确性。核心约束包括：

- 时钟定义（`create_clock`）：指定时钟名称、周期（`-period`）、波形（`-waveform`）和时钟源端口。时钟是整个时序约束体系的根基，所有时序路径都围绕时钟定义展开。
- 输入延迟（`set_input_delay`）：定义外部信号到达输入端口的延迟，代表了芯片外部的时序预算。输入延迟的值来自系统级时序分析，通常由板级 PCB 走线延迟加上上游芯片的时钟到输出（Clock-to-Output）时间组成。
- 输出延迟（`set_output_delay`）：定义输出信号在芯片外部需要的建立时间，代表了接收端对外部信号的时序要求。
- 时钟不确定性（`set_clock_uncertainty`）：为建立/保持时间检查增加余量，涵盖时钟抖动（Jitter）、偏斜（Skew）和额外的设计余量。
- 输入/输出驱动和负载：`set_driving_cell` 和 `set_load` 指定端口的外部驱动能力和负载电容，使工具能计算准确的端口延迟。

### 优化策略

综合工具的优化引擎可以根据设计目标选择不同的侧重点。时序驱动优化（Timing-Driven Optimization）以建立时间违例（Setup Violation）为第一优先级：工具计算每条路径的到达时间（Arrival Time）与要求时间（Required Time），在违例路径上优先进行逻辑重构、门尺寸调整或插入 buffer。面积驱动优化（Area-Driven Optimization）在时序已满足的前提下，通过门尺寸下调和逻辑合并来最小化总面积。

线负载模型（Wire Load Model, WLM）在物理信息缺失的早期阶段估算互连线延迟。WLM 基于面积统计给出线长与扇出的经验关系，但在深亚微米工艺中，互连线延迟已经超过门延迟，传统 WLM 的误差变得不可接受。为此，现代流程使用物理综合（Physical Synthesis）和拓扑模式（Topographical Mode），在综合阶段引入粗略的布局信息，大幅提升时序估算的准确性。

### Design Compiler 与 Genus 流程实践

Synopsys Design Compiler（DC）是业界最广泛使用的逻辑综合工具，其典型流程通过 Tcl 脚本驱动。标准的 DC 流程分为以下步骤：

1. 设置库和搜索路径：`set target_library` 指定目标标准单元库用于映射，`set link_library` 包含目标库和设计所需的宏单元/IP 库，`set synthetic_library` 包含 DesignWare 组件库。
2. 读入设计：`read_verilog` 或 `read_vhdl` 读入 RTL 源文件，`analyze` 加 `elaborate` 可以精化顶层设计并自动解决层次引用。
3. 施加约束：读入 SDC 文件（`read_sdc`）或通过 Tcl 命令逐条施加约束。典型做法是先施加时钟定义，再施加 I/O 延迟，最后设置面积和功耗目标。
4. 编译与优化：`compile_ultra` 是 DC 最高级别的编译命令，启用 Ultra 优化引擎包括寄存器重定时（Retiming）、高级算术优化、自动门控插入。
5. 输出与报告：`write -format verilog -output design.mapped.v` 输出门级网表，`write_sdc design.sdc` 输出可传递的 SDC，`report_timing`、`report_area`、`report_power` 生成分析报告。

Cadence Genus 的流程与 DC 类似，但使用 `read_hdl` 加 `elaborate` 读入设计，`syn_generic` 执行工艺无关优化，`syn_map` 执行技术映射，`syn_opt` 执行增量优化。Genus 的关键特色是其物理感知综合引擎 iSpatial，可以与 Innovus P&R 紧密集成，通过迭代交换布局信息来提高综合质量。

### 综合质量评估

评估综合结果的质量需要从多个维度审视。时序 QoR（Quality of Results）：最差负余量（Worst Negative Slack, WNS）和总负余量（Total Negative Slack, TNS）应趋近于零。面积利用率：综合面积与库单元面积之比。设计规则违例（DRC）：包括 max_transition、max_capacitance、max_fanout 违例，理想情况下应全部通过。功耗估算：使用工艺库的标称功耗参数和粗略活动数据。门控覆盖率：被门控的寄存器比例。此外还要检查综合前后的逻辑等价性（LEC），确保优化变换没有改变功能。

### 综合中的增量优化与 ECO

增量综合（Incremental Synthesis）在初始综合结果基础上进行局部优化而不重跑完整流程。典型场景包括：修复特定路径的 DRC 违例、轻微时序违例（WNS > -50ps）的缓冲器插入或门尺寸调整、以及局部功耗优化。增量综合命令（`compile_ultra -incremental` 在 DC 中或 `syn_opt` 在 Genus 中）在已有网表上运行，仅对违例区域进行局部重综合，保留非违例部分的优化成果。

**重定时（Retiming）**是综合中最强大但也最危险的优化技术——工具将寄存器沿着组合逻辑路径向前或向后移动，将长路径的延迟"借给"短路径，在不改变周期数的前提下均衡路径延迟。重定时可以显著改善 WNS（改善幅度可达 20%-40%），但改变了所有寄存器位置——综合后的 LEC 必须使用支持重定时的 SEQ 模式而非默认的 COM 模式，否则所有寄存器比较点都会因为位置改变而报告假不匹配。

### 综合中的有限状态机优化

综合工具对有限状态机（Finite State Machine, FSM）执行专门的优化变换。**状态编码优化（State Encoding Optimization）**根据状态数量和转移复杂度选择最优编码方式——二进制编码（面积最小但解码复杂）、独热码（One-Hot, 速度最快但寄存器开销大，适合 ≤32 状态）、格雷码（Gray Code, 相邻状态仅变化 1 位，功耗最低）。**安全状态恢复（Safe State Recovery）**在综合中插入额外逻辑使 FSM 在未使用状态的编码被单粒子翻转（SEU）触发时能自动回到有效状态——这对于航空航天和汽车电子设计是强制性要求。综合工具还可以自动将显式风格和隐式风格的 RTL 描述统一优化为最优的门级 FSM 实现。

### 层次化综合与模块边界优化

大规模 SoC 设计中通常采用层次化综合（Hierarchical Synthesis）策略——将顶层芯片分为多个模块，每个模块独立综合后再在顶层集成。层次化综合的核心挑战是**边界优化（Boundary Optimization）**——模块端口（Interface Ports）的时序约束必须在综合阶段正确设置，否则模块集成后会在跨边界时序路径上出现大量违例。DC 的 `compile_ultra -gate_clock` 和 Genus 的 `syn_opt -boundary_optimization` 可在综合时推断模块端口的驱动和负载条件，对跨模块的关键路径执行逻辑重构（如复制的组合逻辑下沉到下游模块的输入端）。**接口逻辑模型（Interface Logic Model, ILM）**是层次化综合中的关键抽象——模块综合完成后生成包含端口时序弧和寄存器的精简模型，上层集成和顶层 STA 使用 ILM 而非完整网表，在保证时序精度的前提下减少 80% 的计算量。

## 关键要点

- 综合三阶段：RTL 精化（推断高层结构）到工艺无关优化（布尔级逻辑简化）到技术映射（映射到标准单元库的门级网表），三个阶段缺一不可
- `create_clock` 和 `create_generated_clock` 是时序约束的根基，时钟定义错误会导致整个综合结果无效，是 ASIC 流程中的第一因
- 时序驱动优化（Timing-Driven）以建立时间违例修复为首要目标，面积驱动优化（Area-Driven）在时序闭合后再压缩面积，两者是先达标再节流的逻辑
- 物理感知综合（Physical-Aware Synthesis）将布局信息反馈到综合阶段，大幅减少了传统流程中综合与布局之间的时序迭代；拓扑模式（Topographical Mode）可使时序估算精度从 ±30% 提升至 ±10%
- 约束完整性检查（`check_timing`）应在综合前强制执行——发现未约束的路径、不合理的多周期约束或缺失的时钟定义
- 综合输出包括门级网表（Verilog）、SDC 文件（可传递到下游工具）、延迟信息（SDF 或工具数据库）和设计约束报告
- 门控时钟（Clock Gating）的插入通常由综合工具自动完成（通过 `set_clock_gating_style` 指令），能节省 20%-40% 的动态功耗；最小门控位宽参数（通常 3-4 位）是门控插入的灵敏度调节——低于此位宽的寄存器组不值得插入独立的 ICG
- 综合中的 `set_dont_touch` 属性保护关键路径和手工设计的电路不被工具意外修改，必须谨慎使用
- Design Compiler 的 `compile_ultra` 和 Genus 的 `syn_opt` 是最高级别的综合命令，启用了物理感知、寄存器重定时和高级算术优化
- 综合后的形式等价检查（RTL vs Gate LEC）是质量验证的第一关——需要确认布尔级优化没有改变设计的功能语义；寄存器重定时后必须使用 LEC 的 SEQ 模式而非默认 COM 模式
- 算术优化（Arithmetic Optimization）将 RTL 中的 `+`, `*` 等运算符映射到 DesignWare 数据通路组件——乘法器的选择（Wallace Tree, Booth, 流水线级数）对时序和面积有决定性影响
- 综合阶段必须为测试逻辑（如扫描链 MUX）留出时序裕度——扫描 MUX 增加功能路径延迟约 10-30ps（28nm 工艺），在综合的时序预算中需要预先计入
- 层次化综合（Hierarchical Synthesis）中边界优化是关键——模块端口的时序约束偏差是跨模块路径违例的主要根源
- 接口逻辑模型（ILM）是层次化综合中的关键抽象——在保持时序精度的同时减少 80% 的计算量
- FSM 优化中独热码（One-Hot）速度最快但寄存器开销大；格雷码功耗最低；二进制编码面积最小——综合工具根据状态数和时序约束自动选择

## 与其他概念的关系

- [[asic-flow/concepts/static-timing-analysis|静态时序分析（STA）]] — 综合后的网表需要通过 STA 验证时序，SDC 约束在综合和 STA 中共享；综合阶段的线负载模型（WLM）精度有限——STA 在获得反标寄生参数后可精确评估综合与最终时序之间的偏差
- [[asic-flow/concepts/clock-tree|时钟树综合（CTS）]] — 综合阶段假定时钟理想抵达，CTS 阶段才引入真实的时钟延迟和偏斜；通常预留时钟不确定性（Clock Uncertainty）的 50%-80% 用于补偿后续 CTS 引入的偏斜
- [[asic-flow/concepts/place-and-route|布局布线（P&R）]] — 综合输出的门级网表是 P&R 的直接输入，物理综合的目标就是减少综合与 P&R 之间的时序鸿沟；综合的单元分配（Cell Sizing）影响 P&R 的布局密度
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — 门控时钟是综合阶段的核心低功耗技术，门控使能信号的生成逻辑直接影响功耗效率；综合阶段的多 Vth 分配决定漏电-速度的初始折中
- [[asic-flow/concepts/signoff|签核（Signoff）]] — 综合后的 LEC 是签核的第一个正式关卡，综合质量直接影响后续所有阶段的收敛难度
- [[asic-flow/concepts/dft|可测试性设计（DFT）]] — 扫描替换在综合后执行——综合必须为扫描 MUX 留出时序裕度，综合阶段的 DRC 检查需要覆盖 DFT 引入的额外约束
- [[asic-flow/concepts/physical-verification|物理验证（Physical Verification）]] — 综合输出的门级网表虽然尚未有版图信息，但门级 DRC（max_transition, max_capacitance）在此阶段就需要满足——这些门级 DRC 违例在后期版图中修复的代价更大
