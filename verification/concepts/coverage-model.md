---
type: concept
aliases:
  - 功能覆盖率
  - Functional Coverage
  - Coverage-Driven Verification
  - 覆盖率驱动验证
tags:
  - asic
  - verification
  - coverage
  - functional-coverage
  - covergroup
  - cdc
source_spec: "IEEE 1800-2023 SystemVerilog LRM Chapter 19 (Coverage); Mentor/Siemens, Coverage Cookbook; Synopsys, VCS Coverage User Guide"
---

# 覆盖率模型（Coverage Model）

覆盖率模型（Coverage Model）是覆盖率驱动验证（Coverage-Driven Verification, CDV）方法论的核心组件，它用可量化的指标回答 "验证是否充分" 这一根本问题。在功能验证中，覆盖率分为两大类：**代码覆盖率（Code Coverage）** 和 **功能覆盖率（Functional Coverage）**。代码覆盖率由仿真工具自动收集，反映 RTL 代码的执行情况；功能覆盖率由验证工程师显式定义，描述测试计划中列出的功能点和场景是否被激励触发。两者缺一不可——代码覆盖率 100% 而功能覆盖率 0% 意味着所有代码都运行过但没有检验任何功能意图，反之亦然。

## 原理

### 代码覆盖率

代码覆盖率是仿真器在运行时自动追踪并统计的指标，不需要用户编写额外的代码。它包括四个基本维度：(1) **行覆盖率（Line Coverage）**——统计每条可执行语句是否至少被执行过一次；(2) **翻转覆盖率（Toggle Coverage）**——统计每个 bit 是否至少经历过 0→1 和 1→0 两种翻转；(3) **条件/分支覆盖率（Branch/Condition Coverage）**——统计 `if-else`、`case` 语句中每个分支是否都被进入过，以及组合条件中每个子条件对最终结果的影响是否都被测试；(4) **FSM 覆盖率（FSM Coverage）**——统计状态机中每个状态是否被访问、每条状态转移弧是否被遍历。代码覆盖率是验证充分性的必要条件但非充分条件——100% 行覆盖率不代表设计逻辑正确，因为代码覆盖率只证明 "被执行过"，不证明 "行为符合预期"。

### 功能覆盖率与 Covergroup

功能覆盖率由验证工程师通过 SystemVerilog 的 `covergroup` 结构显式定义。`covergroup` 是覆盖率模型的基本容器，包含多个 `coverpoint`（采样点）和可选的 `cross`（交叉覆盖）。`coverpoint` 定义了关心的信号值或表达式，并通过 `bins` 将值域划分为有意义的桶（Bucket）：**自动分箱（`bins auto`）** 让仿真器自动创建桶；**显式分箱（`bins name = {values}`）** 由用户精确指定每个桶包含的值；**非法分箱（`illegal_bins`）** 标记不允许出现的值，一旦命中仿真立即报错（而非仅覆盖率统计）；**忽略分箱（`ignore_bins`）** 排除用户不关心的值域。`cross` 语法定义两个或多个 `coverpoint` 的笛卡尔积（Cartesian Product），用于捕捉多维功能空间中不同条件组合的覆盖情况——例如将操作码（Opcode）和寻址模式（Addressing Mode）交叉，确保每种指令类型下每种寻址模式都被测试过。

### 覆盖率收集与采样策略

Covergroup 必须通过 `sample()` 方法被显式触发，采样时机直接影响覆盖率数据的准确性。常用的采样策略包括：(1) 在 Monitor 的 `run_phase` 中，每收到一个事务（Transaction）就调用 `sample()`；(2) 在 Interface 中，通过 `always @(posedge clk)` 在每个时钟沿采样——适用于以周期级交互为关注点的场景；(3) 在 Scoreboard 中采样——适用于需要检查内部计算结果的覆盖率。Covergroup 支持 `option.per_instance = 1` 使每个实例独立统计覆盖率，以及 `option.goal = 95` 设定覆盖率目标阈值。`type_option.weight = 0` 可以将特定 covergroup 排除在总体覆盖率计算之外，适用于调试性或辅助性的 covergroup。

### 覆盖率驱动的验证流程

CDV 流程是一个迭代闭环：(1) 根据验证计划（Verification Plan, vPlan）编写 Covergroup 定义；(2) 运行回归测试并收集覆盖率数据；(3) 分析覆盖率缺口（Coverage Hole）——哪些 bin 未被命中；(4) 根据缺口调整约束随机参数范围或编写定向测试（Directed Test）；(5) 重新运行并评估覆盖率收敛。覆盖率收敛过程中，通常先使用无偏随机（Unconstrained Random）快速覆盖容易命中的功能点（快速达到 70-80%），再通过约束调整（Tuning Constraints）和定向测试（Directed Test）逐一消除剩余的覆盖率缺口。覆盖率合并（Coverage Merge）工具（如 URG、IMC）可以聚合多次回归运行（不同随机种子、不同配置）的覆盖率数据，生成总体验证覆盖视图。

## 关键要点

- 代码覆盖率是工具自动产生的客观度量，功能覆盖率是验证工程师定义的主观意图——两者结合构成 CDV 的完整度量体系
- 100% 代码覆盖率 + 100% 功能覆盖率不等于验证完成——还需确保功能覆盖率模型本身是完整的（vPlan 中的所有测试点都映射到了 coverpoint）
- `illegal_bins` 不只是覆盖率排除机制，更是功能检查机制——命中即报错，等同于属性检查
- `cross` 的笛卡尔积可能导致 Bin 数量爆炸（Cross Explosion）：3 个 coverpoint 各含 10 个 bin → 交叉产生 1000 个 bin，实际逻辑中很多组合可能永远不可能出现
- 覆盖率目标的设置具有项目特异性：安全关键领域（如 ISO 26262）可能要求 100% 功能覆盖率 + 100% 代码覆盖率的严格证据链；消费电子领域常规项目以 95%+ 为目标
- `covergroup` 中 `option.at_least = N` 表示每个 bin 需要被命中至少 N 次才视为覆盖（默认 1），对于随机性较强的功能点可以设置为 3~5 降低误报
- `transition bins` 用于捕获信号的值跳转覆盖（如 `3'b000 => 3'b010`），对于验证 FSM 的状态转移路径或接口协议的事务顺序特别有用
- SystemVerilog 的 `get_coverage()` 方法可以在仿真运行中获取实时覆盖率（Real-Time Coverage），实现覆盖率触发的激励调整（Coverage-Aware Randomization）

## 与其他概念的关系

- [[verification/concepts/constrained-random|约束随机验证]] — Covergroup 定义 "验证什么"，约束随机引擎定义 "激励空间"，两者通过覆盖率缺口驱动约束迭代收敛
- [[verification/concepts/uvm-methodology|UVM 验证方法学]] — UVM Monitor/Scoreboard 是 Covergroup 采样的标准位置，RAL 内建寄存器域覆盖率
- [[verification/concepts/testbench-architecture|验证平台架构]] — 覆盖率采样通常集成在 Monitor（采集DUT 观测信号）和 Scoreboard（采集内部计算正确性）中
- [[verification/concepts/systemverilog-assertions|SystemVerilog 断言（SVA）]] — `cover property` 提供基于属性的覆盖率，与 Covergroup 互补构成完整的可观测性
