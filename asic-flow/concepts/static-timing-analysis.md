---
type: concept
aliases:
  - STA
  - 静态时序分析
  - Static Timing Analysis
tags:
  - asic
  - asic-flow
  - timing
  - sta
  - signoff
source_spec: "Synopsys PrimeTime User Guide, Cadence Tempus User Guide, Bhasker & Chadha Static Timing Analysis for Nanometer Designs"
---

# 静态时序分析（Static Timing Analysis）

静态时序分析（Static Timing Analysis, STA）是数字 IC 设计签署（Signoff）的核心方法。与动态仿真不同，STA 不需要输入测试向量（Test Vector），而是穷举式地分析芯片中所有可能的时序路径，在 PVT（Process-Voltage-Temperature）最坏条件下验证整个设计的时序是否满足要求。STA 的速度比门级仿真快数个数量级，并且提供 100% 的路径覆盖率，是现代 ASIC 流程中不可或缺的时序验证手段。

## 原理

### 建立时间与保持时间检查

时序检查的核心是建立时间（Setup Time）和保持时间（Hold Time）验证。建立时间要求数据信号必须在时钟有效沿（Capture Edge）之前的一段最小时间内稳定——这段时间就是寄存器的建立时间要求（T_setup）。如果数据到达太晚，寄存器可能采样到错误的值或进入亚稳态。保持时间要求数据信号在时钟有效沿之后的一段最小时间内必须保持稳定——这段时间就是寄存器的保持时间要求（T_hold）。如果数据变化太早（在上一个值被可靠锁存之前就翻转），寄存器同样可能采样失败。

STA 工具（如 Synopsys PrimeTime、Cadence Tempus）通过计算以下不等式来验证每条路径。建立时间检查：T_launch + T_clk2q_max + T_comb_max + T_setup < T_capture + T_period - T_uncertainty_setup，即从发射时钟沿经发射寄存器时钟到输出延迟（T_clk2q）、组合逻辑最大延迟（T_comb_max）、再加建立时间要求，必须小于捕获时钟沿的时间。保持时间检查：T_launch + T_clk2q_min + T_comb_min > T_capture + T_hold + T_uncertainty_hold，即从发射时钟沿经最小延迟的数据路径，必须晚于捕获寄存器的保持时间要求。

建立违例（Setup Violation）表示路径太慢，通常通过降低频率、减少组合逻辑级数或增大驱动能力来修复。保持违例（Hold Violation）表示路径太快（数据在新值被锁存前就冲到了），通常通过插入延迟单元或增加 buffer 来修复。建立和保持的修复手段存在矛盾——增加延迟能修保持但可能恶化建立，需要在二者之间平衡。

### 时序路径分类

STA 按路径的起点和终点分为四种类型：

1. 输入到寄存器（in2reg, Input-to-Register）：起点是芯片的输入端口，终点是内部寄存器的数据输入端。这类路径的时序约束来自 `set_input_delay`，代表了芯片外部上游电路的时序预算。
2. 寄存器到寄存器（reg2reg, Register-to-Register）：起点是发射寄存器的时钟端（经 clk2q 延迟），终点是捕获寄存器的数据输入端。这是占比最大的路径类型，时序受时钟周期和组合逻辑延迟的限制。
3. 寄存器到输出（reg2out, Register-to-Output）：起点是内部寄存器的时钟端，终点是芯片的输出端口。时序约束来自 `set_output_delay`，代表了芯片外部下游电路的建立时间要求。
4. 输入到输出（in2out, Input-to-Output）：起点是输入端口，终点是输出端口，路径中不经过任何寄存器。纯组合逻辑路径需要在设定的输入输出延迟约束下完成传输。

### 时钟定义与约束

准确的时钟定义是 STA 的基础。`create_clock` 定义一个主时钟（Master Clock），指定其名称、周期和波形。`create_generated_clock` 定义由主时钟派生的时钟（如经过分频器产生的二分频时钟），需要指定其源时钟（`-source`）、分频/倍频比例和生成路径上的主触发器。生成时钟的定义至关重要——定义错误会导致整片逻辑的时序计算偏移了实际的锁存触发沿。

时钟延迟（Clock Latency）分为源延迟（Source Latency，芯片外部的时钟网络延迟）和网络延迟（Network Latency，芯片内部的时钟树延迟）。在综合阶段，时钟树尚未实现，网络延迟以模型的估算值代入；在 CTS 之后，可反标（Back-annotate）真实的时钟树延迟。时钟不确定性（Clock Uncertainty）是 STA 中人为施加的余量，用于覆盖抖动（Jitter）、偏斜（Skew）和额外设计余量。建立时间检查使用较大的不确定性，保持时间检查使用较小的不确定性。

### 时序降额与 MCMM 分析

随着工艺缩小，工艺偏差（Process Variation）导致芯片上不同位置的晶体管延迟不完全相同。片上偏差（On-Chip Variation, OCV）通过设置统一的降额因子（Derating Factor）来处理——例如对建立时间的发射路径增加 10% 延迟、捕获路径减少 10% 延迟。然而统一降额过于悲观，先进片上偏差（Advanced OCV, AOCV）根据路径深度和物理距离使用可变的降额因子，更为精确。

多角多模（Multi-Corner Multi-Mode, MCMM）分析是现代 STA 的基本要求。不同的工作模式（Function Mode、Test Mode、Sleep Mode）和不同的 PVT 工艺角（如 SS/0.9V/125C 最慢角、FF/1.1V/-40C 最快角）需要分别进行 STA。建立时间在最慢角和最快时钟下检查，保持时间在最快角和最慢时钟下检查。一个典型设计可能有数十个角（Corner），每个角都有独立的时序报告需要分析。

### 路径组与异常路径约束

STA 工具默认将所有与同一时钟相关的 reg2reg 路径归类为一个路径组（Path Group）。路径组的划分对于时序优化至关重要——工具在每个路径组内独立地对最差路径进行排序和优化。除了默认的时钟分组外，用户还可以通过 `group_path` 命令创建自定义路径组（如 DDR 接口路径组），使关键接口的时序分析独立于普通逻辑。

异常路径约束（Timing Exceptions）用于标注不适用默认单周期时序检查的路径。伪路径（False Path, `set_false_path`）标注从逻辑上不可能被同时激活的路径，如跨异步时钟域的路径（在未同步化的前提下）和静态配置信号的路径。多周期路径（Multi-Cycle Path, `set_multicycle_path`）标注数据需要多个时钟周期才能到达的路径——例如乘法器输出可能允许 2 个周期到达，则其建立时间检查在 2 个周期后进行，保持时间检查的位置也需要通过 `-hold` 选项相应调整。

### STA 分析流程与报告解读

典型的 STA 分析分为三个阶段：首先执行 `read_parasitics` 读入 SPEF（Standard Parasitic Exchange Format）反标寄生参数；然后执行 `update_timing` 计算整个设计的时序；最后通过 `report_timing` 生成指定路径的详细时序报告。

理解时序报告的每一行是 STA 工程师的基本功。一条典型的建立路径报告中包含：起点（Startpoint）和终点（Endpoint）信息、路径类型（Path Group）、路径延迟分解（从发射时钟沿到数据到达的逐级门延迟和线延迟明细）、时钟网络的延迟（包括源延迟和网络延迟）、库建立时间要求、以及最终的 Slack 值。`report_constraint` 可以看到所有违例的分布，`report_analysis_coverage` 可以检查时序分析的覆盖率——未覆盖的检查点（如未约束的端口、三态使能信号等）是潜在的时序风险。

## 关键要点

- STA 无需测试向量，穷举分析所有时序路径，覆盖率 100%，速度比门级仿真快数个数量级——这是它成为签核标准的根本原因
- 建立时间要求数据在时钟沿前稳定（路径太慢则违例），保持时间要求数据在时钟沿后保持（路径太快则违例），两者的修复手段相互矛盾
- 四种时序路径类型（in2reg、reg2reg、reg2out、in2out）每一种的约束来源和优化方法都不同，reg2reg 占比最大
- `create_generated_clock` 的定义必须准确指向源时钟和生成路径上的主节点，定义错误会导致整个时钟域的时序计算全部偏移
- MCMM（Multi-Corner Multi-Mode）要求在不同 PVT 角和不同工作模式下分别分析，一个现代 SoC 设计可能有 50-100+ 个分析角
- OCV（统一降额）到 AOCV（路径深度相关降额）到 POCV/LVF（统计性降额）是时序签核精度持续提升的演进路线
- 建立违例修复手段包括降频、减少逻辑级数、up-size 门、调整寄存器位置；保持违例修复手段包括插入 buffer/delay cell、增加线长
- 时序报告是 STA 分析的核心输出——理解到达时间、要求时间、Slack 和数据路径的每级延迟是时序分析的基本功
- 伪路径（False Path）和多周期路径（Multi-Cycle Path）如果不正确标注，会导致 STA 工具对不存在的违例进行无效优化
- PrimeTime 和 Tempus 均支持分布式多角并行分析（DMSA），可以大幅缩短全角签核时间

## 与其他概念的关系

- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — 综合使用 SDC 约束进行时序驱动优化，综合后的 STA 结果决定是否需要重新综合迭代
- [[asic-flow/concepts/clock-tree|时钟树综合（CTS）]] — CTS 引入真实的时钟延迟和偏斜，STA 使用反标的时钟树延迟替代综合阶段的理想时钟模型
- [[asic-flow/concepts/signoff|签核（Signoff）]] — STA 是时序签核的核心，从 OCV 到 AOCV 到 POCV 到 LVF 的演进是签核精度持续提升的体现
- [[asic-flow/concepts/place-and-route|布局布线（P&R）]] — P&R 中的时钟树实现和互连延迟直接影响 STA 结果，ECO 以 STA 违例为驱动
- [[cross-domain/timing-closure|时序收敛（Timing Closure）]] — 从综合到签核的跨阶段时序优化方法论，STA 是度量时序收敛的唯一标准
