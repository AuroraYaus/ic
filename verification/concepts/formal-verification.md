---
type: concept
aliases:
  - 形式验证
  - Formal Verification
  - Property Checking
  - Model Checking
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

形式验证（Formal Verification）是基于数学证明的验证方法，它使用形式化逻辑和算法来**穷举地证明**设计是否满足给定的属性规范，而不是通过样本测试（仿真）来推断。形式验证保证了给定属性在所有可能的输入组合和状态空间下都成立（或不成立，此时工具给出具体违反序列的一个反例 Counterexample）。形式验证不依赖测试激励——它从设计的状态空间出发，通过数学推导验证属性——因此可以覆盖仿真中无法穷举的 Corner Case。形式验证主要包括两大类：**属性检查/模型检查（Property Checking / Model Checking）** 和 **等价性检查（Equivalence Checking）**。

## 原理

### 属性检查与模型检查

模型检查（Model Checking）将设计建模为一个有限状态转移系统（Kripke Structure），将验证属性表达为时序逻辑公式（Temporal Logic Formula），然后通过状态空间搜索算法验证该属性在整个状态空间中是否恒成立。其数学基础是计算树逻辑（CTL*）和线性时序逻辑（LTL）——SVA 的语义以 LTL 为基础，通过 `disable iff` 扩展了复位语义。

模型检查器的核心算法包括：(1) **显式状态模型检查**——以状态转移图的方式显式枚举状态空间，受状态爆炸限制，适用于小型设计（<10^6 状态）；(2) **符号模型检查（Symbolic Model Checking）**——使用 BDD（Binary Decision Diagram）或 SAT/SMT 求解器隐式编码状态空间，可处理 10^20+ 状态，是现代商用工具的主流方法；(3) **有界模型检查（Bounded Model Checking, BMC）**——将验证范围限制在有限步数（Bound）内。

如果属性不成立，模型检查器生成**反例（Counterexample）**——一条从初始状态出发、一步步到达属性违反状态的精确路径，每一步包含输入值和内部信号值。这个反例可以直接加载到仿真波形中重现，调试效率极高。

### 有界模型检查与 k-归纳

BMC 将 "设计在 k 步内是否可能违反属性" 转化为 SAT 问题求解。对深度有限的 Bug（大多数 RTL Bug 在几十个周期内即可暴露），BMC 是最高效的技术。但 BMC 只能证明在 k 步内没有违反，不保证 k+1 步及以后。

```systemverilog
// Property: FIFO overflow should never occur
assert property (@(posedge clk) !(full && push));
// BMC can prove: no overflow within first N cycles
// BMC cannot guarantee: no overflow at cycle N+1 or beyond
```

**k-归纳（k-Induction）** 通过数学归纳法将有限步证明推广为无限步：(1) Base Case——属性在 0 到 k-1 步成立（BMC 验证）；(2) Inductive Step——如果属性在任意连续的 k 步成立，那么第 k+1 步也必然成立。如果 Induction Step 通过，属性得到完整证明。若不通过，可能是真实违反，也可能是 k 不够大导致归纳假言不够强——需增加 k 或添加辅助不变式（Helper Invariant/Lemma）强化归纳假设。

### 等价性检查（LEC）

等价性检查（Equivalence Checking）形式地证明两个设计表示的功能等价性，最经典的应用是 RTL-vs-Gate 等价性检查（Logic Equivalence Checking, LEC）。

LEC 工作流程：(1) 建立 Compare Points——将两端的时序元件（触发器/寄存器/锁存器）按名称匹配或用户提供的映射文件对应；(2) 构造组合逻辑锥（Logic Cone）——从每个 Compare Point 反向追踪到上游 Compare Points 或输入端口，提取纯组合逻辑函数；(3) 通过 SAT 求解器或 BDD 验证每对对应逻辑锥的布尔等价性。

```text
  RTL:                          Gate-Level Netlist:
  always @(posedge clk)         DFF_X1 q_reg (.D(n5), .CK(clk), .Q(q));
     q <= a & b | c;
                                NAND2_X1 U1 (.A(a), .B(b), .Y(n1));
  logic cone from q:            INV_X1  U2 (.A(n1), .Y(n2));
     f_RTL(a,b,c) = a&b|c       NAND2_X1 U3 (.A(n2), .B(c), .Y(n5));
                                logic cone from q_reg/D:
                                   f_GATE(a,b,c) = ~(~(a&b) & c) = a&b|c
  Comparison: f_RTL ≡ f_GATE ?  YES (verified by SAT)
```

LEC 是 ASIC 流程中最成熟的、使用最广泛的形式验证应用——在综合、DFT 插入、时钟树综合、ECO 等每个网表修改步骤之后都必须通过 LEC 验证。

### 形式验证 vs 仿真：适用场景分工

| 维度 | 形式验证 | 仿真验证 |
|:---|:---|:---|
| 验证方式 | 数学推导，穷举状态空间 | 样本测试，统计推断 |
| 完备性 | 属性得到完整证明（或不成立） | 仅覆盖被激励触发的场景 |
| 设计规模 | IP 级（<10^5 触发器）最有效 | 系统级、大规模 SoC 主要手段 |
| 激励 | 不需要（由工具自主求解） | 必须提供 |
| 调试 | 反例即波形，精准定位 | 需要多次迭代调整激励 |
| 典型应用 | 协议合规、死锁、X-Prop、CDC、LEC | 系统集成、性能验证、低功耗场景 |

工程分工：(1) IP 级——形式验证主导做 Property Proof 和 Bug Hunting；(2) 子系统级——两者结合，形式做接口合规和死锁检测，仿真做端到端数据路径；(3) 芯片级——仿真主导，形式用于关键控制路径（复位控制器、电源管理 FSM）。

### 形式覆盖率与可达性分析

形式覆盖率（Formal Coverage）衡量形式验证属性集合自身完备性。形式工具自动提取设计中的可覆盖点（信号值、多路选择条件、FSM 状态/弧），逐一分析在被 Assumption 约束的合法输入空间内该点是否可达。

- **Reachable**：存在合法的输入序列使该点取指定值 → 形式验证的观测范围覆盖了该点
- **Unreachable**：不存在满足 Assumption 的输入序列 → 该点是假设下的死码（Dead Code）
- **Uncovered**：该点可达但没有任何 Assert/Cover 属性提到该信号 → **验证盲区**

形式覆盖率的核心应用是盲区发现——Uncovered 点标识了现有形式验证属性的薄弱环节，引导验证工程师补充新的 Assert 或 Cover 属性。

### 形式验证的工程挑战

状态空间爆炸（State Space Explosion）是形式验证的根本性挑战：n 个触发器的状态数为 2^n。缓解技术包括：

- **抽象（Abstraction）**：将数据路径信号抽象为自由变量（Black-Boxing），只保留控制逻辑精确建模——数据路径正确性由仿真覆盖，形式验证专注控制逻辑
- **组合推理（Compositional Reasoning）**：将大设计分解为子模块各自做形式验证，再用 Assume-Guarantee 推理组合结论
- **对称归约（Symmetry Reduction）**：利用设计的结构对称性（如多核、多通道）将等价状态折叠
- **Case Splitting**：将复杂属性按互斥的条件分解为多个简单属性，降低单次验证的计算复杂度

商用形式工具（VC Formal、JasperGold、Questa Formal）提供预设的自动检查 "App"：Connectivity Check（信号连接正确性）、Coverage Unreachability（死码发现）、Clock Domain Crossing（自动化 CDC 验证）、Register Check（寄存器读写属性一致性）、X-Propagation（X 态传播分析）。

## 关键要点

- 形式验证使用数学证明替代样本测试——对给定属性，要么给出完整证明（Proven），要么给出具体反例（Falsified），没有 "未确定" 的模糊地带
- Assumption-Guarantee 契约是形式验证的灵魂：Input Assumption 约束合法输入空间，Output Assert 约束设计义务——宽松的 Assumption 可能导致工具报告的反例实际上来自不合法的输入（False Negative）
- LEC 的 Compare Point 映射错误是最常见失败原因——RTL 寄存器名 `tx_fifo_wr_ptr_reg` 与网表 `u_fifo/u_wptr/q_reg[4]` 的名称匹配失败时工具报告不等价，需手动修正映射文件
- X-Propagation 分析是形式验证在数字设计中的杀手级应用：形式工具自动追踪 X 态能否从源头传播到关键输出——这是仿真几乎无法穷举检查的行为
- 形式验证对设计风格有要求：大量异步逻辑、自定时电路、依赖模拟行为的电路难以形式化建模，需要转换为可形式化的等价模型
- "Bug Hunting" 模式是形式验证的低成本入门方式：不做完整 Induction 证明，而是设定 BMC 深度 N 让工具在 N 步内搜索属性违反路径——计算成本远低于完整证明但覆盖率远超仿真
- 形式验证的成熟度已经从 "安全关键领域的特殊工具" 扩展到 "主流 SoC 设计的标准验证组件"，主要驱动力是设计复杂度增长和商用工具的成熟
- 形式验证 Signoff 要求：所有 Assert 属性完成证明（Proven）、所有 Cover 属性被覆盖（Covered）、所有 Assumption 得到验证（Verified）

## 与其他概念的关系

- [[verification/concepts/systemverilog-assertions|SystemVerilog 断言（SVA）]] — SVA 属性是形式验证的输入规范语言，BMC 和 Property Checking 直接以 SVA Property 作为证明目标或反证目标
- [[verification/concepts/coverage-model|覆盖率模型（Coverage Model）]] — 形式覆盖率（Reachability Analysis）与仿真功能覆盖率互补：前者检查属性盲区，后者检查测试盲区
- [[verification/concepts/testbench-architecture|验证平台架构（Testbench Architecture）]] — 形式验证不需要 Testbench 的激励层，但需要 Assumption（输入约束）替代 Driver 的激励生成角色——Assumption 的正确性直接等价于 Testbench 的合法性
- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — LEC 等价性检查是综合后 Signoff 的必选项，保证综合优化（资源共享、状态重编码、时序优化）未改变设计功能
