---
type: concept
aliases:
  - 形式验证
  - Formal Verification
  - Property Checking
  - Model Checking
  - Equivalence Checking
tags:
  - asic
  - verification
  - formal
  - property-checking
  - model-checking
  - equivalence-checking
source_spec: "Clarke, Grumberg & Peled, Model Checking; IEEE 1850 PSL Standard; Synopsys VC Formal User Guide; Cadence JasperGold User Guide"
---

# 形式验证（Formal Verification）

形式验证（Formal Verification）是基于数学证明的验证方法，它使用形式化逻辑和算法来**穷举地证明**设计是否满足给定的属性规范，而不是通过样本测试（仿真）来推断。形式验证保证了给定属性在所有可能的输入组合和状态空间下都成立（或不成立，此时工具给出具体违反序列的一个反例（Counterexample））。形式验证不依赖测试激励——它从设计的状态空间出发，通过数学推导验证属性——因此可以覆盖仿真中无法穷举的 Corner Case。形式验证主要包括两大类：**属性检查/模型检查（Property Checking / Model Checking）**和**等价性检查（Equivalence Checking）**。

## 原理

### 模型检查（Model Checking）

模型检查是形式验证的核心算法。它将设计建模为一个有限状态转移系统（Kripke Structure），将验证属性表达为时序逻辑公式（Temporal Logic Formula，通常使用 SVA 或 PSL 表达），然后通过状态空间搜索算法验证该属性在整个状态空间中是否恒成立。如果属性不成立，模型检查器会生成一个**反例（Counterexample）**——一条从初始状态到达属性违反状态的精确路径，包含每一步的输入值和信号值，可以直接在仿真波形中重现。这一"反例即波形"的特性使得形式验证的调试效率极高：无需反复修改激励、运行仿真、检查波形，形式工具直接展示失败的确切路径。

模型检查的根本性挑战是**状态空间爆炸（State Space Explosion）**——$n$ 个触发器的状态数为 $2^n$，百万寄存器级设计的原始状态空间是天文数字（$2^{10^6}$）。控制复杂度的手段包括：抽象精炼（Abstraction Refinement）——对验证属性不相关的逻辑进行抽象简化；对称规约（Symmetry Reduction）——利用设计的结构对称性合并等价状态；组合推理（Compositional Reasoning）——将大设计分解为子模块独立验证；以及谓词抽象（Predicate Abstraction）——将具体的状态值归约为有限个谓词的真值组合。

### 有界模型检查（BMC）

有界模型检查（Bounded Model Checking, BMC）是一种实用的模型检查技术，它将验证范围限制在有限步数（Bound, $k$）内。BMC 将设计在 $k$ 个时钟周期内的展开逻辑转化为一个 SAT（布尔可满足性）或 SMT（可满足性模理论）问题——如果存在一条长度不超过 $k$ 的路径违反属性，SAT/SMT 求解器将找到它。

BMC 的优势在于：a) 对深度有限的设计（如流水线级数、总线超时计数器）可给出完整证明；b) 对浅层 Bug 的发现效率极高——大部分 RTL Bug 的可反例深度在几十个周期内。BMC 的局限性在于：a) 只能证明在 $k$ 步内没有违反，不保证 $k+1$ 步及以后；b) 对于需要无限深度才能证明的属性（如 Liveness Property，"请求最终一定会收到响应"），BMC 不能给出完整证明。**k-归纳（k-Induction）**是 BMC 的增强——通过证明 (a) 属性在最初 $k$ 步成立，且 (b) 如果属性在任意连续的 $k$ 步成立，那么第 $k+1$ 步也成立——从而将有限步证明推广为无限步证明。

### 等价性检查

等价性检查（Equivalence Checking）形式地证明两个设计表示之间的功能等价性，最经典的应用是 RTL-vs-Gate 等价性检查（Logic Equivalence Checking, LEC）。综合工具将 RTL 转换为门级网表，LEC 工具使用形式算法验证网表与 RTL 的输入输出行为是否在所有输入组合下完全一致。

LEC 的核心算法基于组合逻辑等价性：将 RTL 和网表的时序元件（触发器/寄存器/存储器）按名称或用户映射确认为比较点（Compare Points），然后将两端组合逻辑锥（Logic Cone）的布尔函数通过 SAT 求解器验证所有输出点（End Points）的布尔函数等价。如果存在不等价，LEC 输出导致差异的输入向量和对应的输出差异——类似于 Counterexample。对于 ECO（Engineering Change Order）阶段的手工网表修改，LEC 是确保修改不引入逻辑错误的标准验证手段。LEC 的 Compare Points 映射错误是最常见的等价性检查失败原因——RTL 的 `reg_a` 和网表的 `DFF_X1_a` 未正确对应时工具报告非等价，但实际上是映射问题而非设计问题。

### 形式覆盖率

形式覆盖率（Formal Coverage）与仿真的功能覆盖率对应，但它衡量的不是"测试是否执行到了某场景"，而是"属性的覆盖范围"。形式工具自动分析设计中的可覆盖点（Coverable Points）——包括信号值、条件表达式、FSM 状态/弧——然后逐一检查这些点是否被已有属性集合约束到了具体值（Reachable）或仍可以取任意值（Unreachable Under Property Assumptions）。Unreachable 点表示现有属性没有对该信号施加任何约束——即验证存在"未被属性描述的盲区"。这一分析称为可达性分析（Reachability Analysis）或覆盖率不可达分析（Coverage Unreachability Analysis），用于评估形式属性集合本身是否完备。

### 形式验证 vs 仿真

形式验证和仿真是互补而非替代关系。形式验证的优势在于穷举性——它用数学证明替代统计推断，适合属性检查（每个属性都被穷举证明或给出反例）、死锁/活锁检测（X-Propagation 分析）和边界条件的充分性验证。仿真的优势在于可扩展性——它对设计规模的敏感度远低于形式验证（形式验证的计算复杂度随状态空间指数增长），适合大规模 SoC 的系统级集成测试和性能验证。

工程实践中的典型分工是：a) 模块级（IP-Level）使用形式验证做属性证明和 Bug Hunting；b) 子系统级（Sub-System Level）二者结合——仿真做功能测试，形式做接口协议合规性检查；c) 芯片级（Chip-Level）以仿真为主，形式用于关键控制路径和寄存器配置序列的验证。"Bug Hunting"模式是形式验证的低成本入门方式——使用 `assert property (@(posedge clk) disable iff (rst_n) !(condition))` 搜索违反断言的路径而非证明断言恒成立，降低了计算复杂度。

## 关键要点

- 模型检查的状态空间爆炸是其根本性挑战——$n$ 个触发器的状态数为 $2^n$，需通过抽象精炼、对称规约和组合推理等技术控制复杂度
- 形式验证成功的关键是写好假设-断言契约（Assumption-Guarantee Contract）：输入假设（Assume）定义合法输入空间，输出断言（Assert）定义设计义务——错误的假设会导致"假装没有 bug"（False Positive）
- LEC 的 Compare Points 映射错误是最常见的等价性检查失败原因——RTL 和网表的触发器名称或实例路径不匹配时报告不等价，实际上是映射问题
- X-Propagation 分析是形式验证在数字设计中的杀手级应用——形式工具自动追踪 X 信号是否可能传播到设计的关键输出（触发复位、数据路径），检查 RTL 中复位和初始化的正确性
- 形式工具支持 SVA（SystemVerilog Assertions）和 PSL（Property Specification Language, IEEE 1850）作为属性规范语言，大多数形式工具同时支持二者
- 形式验证的周转时间差异极大——简单属性检查可能几秒完成，复杂的端到端（End-to-End）证明可能需要数小时乃至数天——需要根据复杂度分类调度
- "Bug Hunting"模式降低计算复杂度——形式工具搜索属性违反而非证明属性恒成立，适用于初期设计缺陷爆发期
- 形式验证的成熟度已经从"安全关键领域的特殊工具"扩展到"主流 SoC 设计的标准验证组件"——主要驱动力是设计复杂度增长和形式工具的商业化成熟（JasperGold, VC Formal, Questa Formal）

## 与其他概念的关系

- [[verification/concepts/systemverilog-assertions|SystemVerilog 断言（SVA）]] — SVA 属性是形式验证的输入规范语言，形式工具直接消费 SVA Property 作为证明目标
- [[verification/concepts/coverage-model|覆盖率模型]] — 形式覆盖率（Reachability Analysis）与仿真功能覆盖率互补：前者检查属性盲区，后者检查测试盲区
- [[verification/concepts/testbench-architecture|验证平台架构]] — 形式验证不需要 Testbench（不需要激励/监视器），但需要定义 Assumption（输入约束）以替代 Testbench 的输入驱动角色
- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — LEC 等价性检查是综合后 Signoff 的必选项，保证综合优化未改变功能
