---
type: concept
aliases:
  - 功能覆盖率
  - Functional Coverage
  - Coverage-Driven Verification
  - 覆盖率驱动验证
  - CDV
tags:
  - asic
  - verification
  - coverage
  - functional-coverage
  - covergroup
  - cdv
source_spec: "IEEE 1800-2023 SystemVerilog LRM Chapter 19 (Coverage); Mentor/Siemens, Coverage Cookbook; Synopsys, VCS Coverage User Guide"
---

# 覆盖率模型（Coverage Model）

覆盖率模型（Coverage Model）是覆盖率驱动验证（Coverage-Driven Verification, CDV）方法论的核心组件，它用可量化的指标回答 "验证是否充分" 这一根本问题。在功能验证中，覆盖率分为两大类：**代码覆盖率（Code Coverage）** 和 **功能覆盖率（Functional Coverage）**。代码覆盖率由仿真工具自动收集，反映 RTL 代码的执行情况；功能覆盖率由验证工程师显式定义，描述测试计划中列出的功能点和场景是否被激励触发。两者缺一不可——代码覆盖率 100% 而功能覆盖率 0% 意味着所有代码都运行过但没有检验任何功能意图，反之亦然。

## 原理

### 代码覆盖率的四个维度

代码覆盖率是仿真器在运行时自动追踪并统计的指标，不需要用户编写额外的代码。

| 维度 | 统计内容 | 局限 |
|:---|:---|:---|
| **行覆盖率（Line）** | 每条可执行语句是否至少被执行过 | 执行过不等于逻辑正确 |
| **翻转覆盖率（Toggle）** | 每位信号是否经历过 0→1 和 1→0 | 不关联翻转的语义正确性 |
| **分支覆盖率（Branch）** | `if-else`/`case` 每个分支是否都被进入过 | 组合条件的子条件独立影响未区分 |
| **条件覆盖率（Condition）** | 组合条件中每个子条件对结果的影响是否都独立测试 | 仅存在于有 MC/DC 能力的工具中 |
| **FSM 覆盖率（FSM）** | 每个状态是否被访问、每条状态弧是否被遍历 | 仅覆盖显式状态机，不覆盖隐式状态 |

代码覆盖率是验证充分性的**必要条件但非充分条件**。一个典型反例：一个 ALU 的加法运算中，如果运算逻辑有 Bug 将 5+3 误算为 9 而非 8，代码覆盖率仍为 100%（加法器的所有行都被执行了），但功能是错误的。代码覆盖率不能替代功能覆盖率，但可以作为功能覆盖率模型的完整性检查——如果功能覆盖率声称已验证 "乘法" 操作但对应 RTL 代码的乘法路径行覆盖率为 0%，说明功能覆盖率采样位置有误。

### 功能覆盖率：Covergroup 结构

功能覆盖率由验证工程师通过 SystemVerilog 的 `covergroup` 结构显式定义。一个完整的 Covergroup 结构示例如下：

```systemverilog
covergroup cg_alu_ops @(posedge clk);
    option.per_instance = 1;    // Each instance has independent coverage
    option.goal = 95;           // 95% coverage is the target
    type_option.weight = 1;     // Include in overall coverage calculation

    // Coverpoint 1: operation type
    cp_opcode: coverpoint alu_op {
        bins add = {ADD};
        bins sub = {SUB};
        bins mul = {MUL};
        bins logic_ops = {AND, OR, XOR, NOT};
        illegal_bins reserved = {5, 6, 7};  // Error if hit
        ignore_bins unused = {15};           // Don't care
    }

    // Coverpoint 2: operand sign combinations
    cp_sign: coverpoint {op_a[31], op_b[31]} {
        bins pos_pos = {2'b00};
        bins pos_neg = {2'b01};
        bins neg_pos = {2'b10};
        bins neg_neg = {2'b11};
    }

    // Cross: opcode × sign combinations
    cr_op_sign: cross cp_opcode, cp_sign;
endgroup
```

### Coverpoint 分箱（Bins）策略

`coverpoint` 通过 `bins` 将值域划分为有意义的桶（Bucket），分箱策略直接影响覆盖率模型的精确度和灵敏度：

- **自动分箱（`bins auto`）**：仿真器自动为每个可能的取值创建 bin。对 8-bit 信号产生 256 个 bin——适用于粗粒度的初步覆盖率采集，但缺乏语义分组
- **显式分箱（`bins name = {values}`）**：由用户按功能语义分组。例如将 `ADD` 和 `ADC`（带进位加）归入同一 bin、`SUB` 和 `SBC` 归入另一 bin——这样的分组使得覆盖率缺口直接映射回验证计划的功能点
- **非法分箱（`illegal_bins`）**：标记不允许出现的值，命中时仿真器报错。这不只是覆盖率排除机制，更是功能正确性检查机制
- **忽略分箱（`ignore_bins`）**：排除用户不关心的值域，不计入覆盖率分子和分母。常用于排除保留字段、未实现的操作码等

### 交叉覆盖率与 Bin 爆炸

`cross` 语法定义两个或多个 `coverpoint` 的笛卡尔积（Cartesian Product），用于捕捉多维功能空间中不同条件组合的覆盖情况。Cross 覆盖率是功能覆盖率中最强大也最危险的特性：

```systemverilog
// Dangerous: 3 coverpoints × 10 bins each = 1000 cross bins
cr_all: cross cp_a, cp_b, cp_c;  // Bin explosion!

// Safer: selective cross with ignore for unrealizable combinations
cr_selective: cross cp_op, cp_addr {
    bins auto_bins = cross cp_op, cp_addr;
    ignore_bins user_only = cr_selective with
        (cp_op == KERNEL_MODE && cp_addr inside {[0:4095]});
    // Exclude: kernel mode accessing user-space addresses (impossible by spec)
}
```

防止 Cross Bin 爆炸的策略：(1) 使用 `ignore_bins` 排除规范保证不可能出现的组合；(2) 使用 `binsof()` 在 cross 中施加条件过滤；(3) 将大 cross 拆分为多个小 cross，每个针对特定子场景；(4) 使用 `cross_auto_bin_max` 选项限制自动交叉 bin 的最大数量（通常设为 128 或 256）。

### 覆盖率收集的采样策略

Covergroup 必须通过 `sample()` 方法被显式触发，采样时机是覆盖率准确性的关键：

- **Monitor 采样**（推荐）：在 Monitor 的 `run_phase` 中，每收到一个事务（Transaction）调用 `sample()`。将覆盖率采样与观测层绑定，确保覆盖率反映的是 DUT 实际发生的行为
- **Interface 采样**：通过 `always @(posedge clk)` 在每个周期采样。适用于周期级精度的覆盖率需求（如流水线级间寄存器的值分布），但产生大量采样事件
- **Scoreboard 采样**：在 scoreboard 的比较逻辑中采样。适用于需要检查 DUT 内部计算结果准确性的覆盖率场景

`covergroup` 的关键选项：
- `option.per_instance = 1`：多个实例独立统计覆盖率
- `option.goal = 95`：覆盖率目标阈值
- `option.at_least = N`：每个 bin 至少命中 N 次才算 covered（默认 1，对随机性强的点建议 3-5）
- `type_option.weight = 0`：将该 covergroup 排除在总体覆盖率计算之外

### 覆盖率驱动验证（CDV）流程

CDV 流程是一个迭代闭环模型：

1. **验证计划（vPlan）**：将设计规范分解为可测试的功能点，每个功能点对应一个或多个 coverpoint/bin
2. **Covergroup 编码**：根据 vPlan 编写覆盖率模型，确保 vPlan 到 bin 的映射完整且无冗余
3. **回归运行**：运行多种子、多测试的回归仿真，收集覆盖率数据
4. **覆盖率分析**：使用覆盖率合并工具（URG/IMC/vManager）聚合数据，识别覆盖率缺口（Coverage Hole）
5. **约束调整**：根据缺口调整随机约束参数或编写定向测试（Directed Test）以覆盖特定组合
6. **重新运行**：迭代步骤 3-5，直到覆盖率收敛到目标

覆盖率收敛的典型曲线：无偏随机快速覆盖 70-80%（低悬果实），约束调整再覆盖 80-95%（需要针对性引导），定向测试填补最后 5%（极其冷门的 corner case）。

### 覆盖率合并与分级管理

覆盖率合并（Coverage Merge）是 CDV 的基础操作：将多次回归运行（不同随机种子、不同测试用例、不同配置参数）的覆盖率数据合并，生成总体验证覆盖视图。覆盖率分级管理在多层级验证中尤为重要：IP 级覆盖率必须达到 100%（所有 feature 在 IP 级被独立验证），子系统级覆盖率补充跨 IP 交互的覆盖率，芯片级覆盖率验证集成场景。

## 关键要点

- 代码覆盖率 100% + 功能覆盖率 100% 不代表验证完成——还需验证覆盖率模型本身是完整的：vPlan 中的所有测试点都已映射到 coverpoint，且 bin 划分粒度合理
- `illegal_bins` 命中即报错——这使得 Covergroup 不仅是覆盖率度量工具，也是功能检查工具，兼具 Coverage 和 Checking 双重职能
- Transition bins 语法 `bins t1 = (3'b000 => 3'b010)` 用于捕获信号的值转移覆盖——验证 FSM 状态转移路径或总线协议的事务序列时比静态值 bin 更有信息量
- `cross_auto_bin_max` 选项限制自动交叉 bin 的数量上限（通常设为 128 或 256），超过上限时工具发出警告，提示用户需要显式管理交叉 bin
- `get_coverage()` 方法返回 0-100 的实时覆盖率百分比，配合仿真时间回调可实现 Run-Time Coverage Closure——在仿真运行中动态调整激励策略
- 加权平均覆盖率（Weighted Average Coverage）中，关键功能点的 Covergroup 权重设为 2-5 倍于辅助 Covergroup，使总覆盖率指标更准确地反映验证健康度
- 覆盖率模型也有代码质量要求：Covergroup 代码量通常为 DUT RTL 代码量的 20-40%，过多暗示过度细化（Over-Specification），过少则覆盖不足
- 覆盖率评审（Coverage Review）是验证 Signoff 的必经环节——验证经理与设计经理一起审查覆盖率数据库，确认每个 Uncovered Bin 是否属于合法豁免（Waiver）还是真正遗漏

## 与其他概念的关系

- [[verification/concepts/constrained-random|约束随机验证（CRV）]] — Covergroup 定义 "验证什么"，约束随机引擎定义 "激励空间"，两者通过覆盖率缺口反馈驱动约束迭代收敛，构成 CDV 的闭环核心
- [[verification/concepts/uvm-methodology|UVM 验证方法学]] — UVM Monitor/Scoreboard 是 Covergroup 采样的标准位置，RAL 内建寄存器域覆盖率，`uvm_subscriber` 提供标准化的覆盖率收集接口
- [[verification/concepts/testbench-architecture|验证平台架构（Testbench Architecture）]] — 覆盖率采样集成在 Monitor（观测 DUT 外部信号）和 Scoreboard（检查内部正确性），回归报告汇总覆盖率收敛仪表盘
- [[verification/concepts/systemverilog-assertions|SystemVerilog 断言（SVA）]] — `cover property` 提供基于属性的覆盖率，与 Covergroup 的结构化覆盖率互补，共同构成完整的可观测性
