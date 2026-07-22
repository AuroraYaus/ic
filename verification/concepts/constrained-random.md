---
type: concept
aliases:
  - 约束随机验证
  - Constrained-Random Verification
  - CRV
tags:
  - asic
  - verification
  - constrained-random
  - stimulus
  - crv
  - randomization
source_spec: "IEEE 1800-2023 SystemVerilog LRM Chapter 18 (Constrained Random Value Generation); Spear & Tumbush, SystemVerilog for Verification (3rd Ed.)"
---

# 约束随机验证（Constrained-Random Verification, CRV）

约束随机验证（Constrained-Random Verification, CRV）是现代功能验证的核心方法论，其基本思想是：验证工程师不编写逐个测试用例的确定激励，而是定义激励的合法空间（通过约束，Constraints），然后由仿真器的随机求解器（Random Solver）在合法空间内生成大量随机测试向量。CRV 相较于传统定向测试（Directed Test）的核心优势在于它可以发现验证工程师未预料到的边界条件和 Corner Case——定向测试覆盖验证者 "已知的需要测试的场景"，而随机验证覆盖 "可能存在的未知问题"。CRV 与覆盖率模型（Coverage Model）配合构成 CDV 闭环：随机生成 → 收集覆盖率 → 分析缺口 → 调整约束 → 重新随机生成。

## 原理

### 随机变量声明

SystemVerilog 提供了 `rand` 和 `randc` 两种随机变量修饰符。`rand` 声明的变量在每一次 `randomize()` 调用时独立地抽取随机值，各变量之间以及同变量的连续随机化之间没有记忆性——这意味着同一个值可以连续出现多次。`randc`（Cyclic Random）保证在枚举完所有可能值之前不会重复，适用于需要遍历性覆盖但又不希望产生定向测试的场景——例如仲裁器验证中确保所有请求源都被轮询到。`rand` 支持 `bit`、`logic`、`integer`、枚举（`enum`）、结构体（`struct`）以及动态数组等几乎所有 SystemVerilog 数据类型。特别地，`rand bit [7:0] data[];` 可以声明元素的个数也是随机的动态数组，由 `data.size` 作为内建随机属性控制。

### 约束块

约束块（Constraint Block）使用 `constraint c_name { ... }` 定义随机变量的合法空间。约束块内部是一个或多个关系表达式，求解器将这些表达式作为联立方程求解，找到一组使所有约束同时满足的变量赋值。约束支持多种运算：(1) **值域约束**——`data inside {[0:255]};` 使用 `inside` 关键词，支持区间、枚举列表和反转 `!()`；(2) **蕴含约束**——`mode == READ -> addr inside {[0:1023]};` 使用 `->` 表示条件推导（注意与 SVA 蕴含的区分）；(3) **if-else 约束**——`if (mode == WRITE) { data < 256; } else { data > 256; }`；(4) **分布约束**——`dist` 操作符允许为不同值分配权重：`addr dist {0 := 1, [1:255] := 2, [256:1023] := 1};`（`:=` 表示每个值独立权重，`:/` 将权重均分到范围内的所有值）；(5) **solve-before 约束**——`solve A before B;` 指导求解器在求解 B 之前先确定 A 的值，用于处理约束间的依赖关系和优化求解顺序。

### 求解器基础

约束求解器（Constraint Solver）是一个基于约束满足问题（CSP, Constraint Satisfaction Problem）的求解引擎。求解器的基本工作流程为：(1) 解析所有活跃约束块的表达式，构建约束图（Constraint Graph）——图中节点为随机变量，边为变量间的约束关系；(2) 通过 solve-before 指令或自动推理确定变量求解顺序；(3) 按顺序依次为每个变量随机分配值，每次分配后检查是否满足所有相关约束，若不满足则回溯（Backtracking）或重新随机。求解器的性能受约束复杂度和变量空间的乘积影响——过于紧密耦合的约束链可能导致求解器需要大量回溯尝试才能找到合法解，极端情况下求解失败（Randomization Failure），此时 `randomize()` 返回 0，需要检查 `$fatal` 或 `assert(randomize())` 来捕获这一错误。

### 约束继承与覆盖

UVM 验证环境中的随机类使用继承机制实现约束复用和定制。子类可以添加新的约束变量和约束块，对父类的随机空间做追加限制。`constraint` 块可以声明为 `soft`（软约束），当与后续约束产生冲突时，求解器优先丢弃软约束，保留硬约束以满足求解。这为层叠式约束（Layered Constraints）提供了灵活性——基础 Sequence Item 的约束定义通用的合法空间，继承的子类通过硬约束进一步缩窄空间，测试层通过 `with()` 内联约束追加最终限制。

### 内联约束与 pre/post_randomize

`randomize() with { constraints }` 语法允许在调用点直接追加内联约束，而不需要修改类定义。内联约束的优先级最高，会覆盖类定义中的同名约束。例如 `tx.randomize() with { length > 64; length < 128; }` 在保持类内所有其他约束不变的前提下将 `length` 限制到子范围。`pre_randomize()` 和 `post_randomize()` 是 `randomize()` 执行前后自动调用的回调（Callback）方法：`pre_randomize()` 常用于在随机化之前设定非随机的初始条件（如设置 `addr.align = 4;`）；`post_randomize()` 常用于根据随机结果计算派生值（如根据 `length` 计算 CRC 校验值）或对随机结果做后处理校验。

## 关键要点

- `rand` 是独立随机（有放回），`randc` 是循环随机（无放回遍历），后者适用于遍历型覆盖场景但会降低随机多样性
- 约束求解是 NP 完全问题——求解器使用启发式算法（如 AC-3 弧相容传播）而非暴力枚举，因此复杂约束的解空间均匀性是近似保证而非严格均匀
- `dist` 的权重控制是引导随机分布的关键工具，`:=` 给每个值独立权重使 "热点路径" 有更高的命中率
- `randomize() with {}` 的内联约束优先级最高，其次是子类硬约束，再次是父类硬约束，最后是软约束——这一优先级链保证了约束的渐进式精炼
- 过于紧密的约束可能导致求解器失败（返回 0），应在验证环境中用 `assert(randomize()) else `uvm_fatal`...` 捕获随机失败并给出诊断信息
- 求解器的随机种子（Random Seed）决定了整个随机序列：相同的种子产生相同的激励序列——在回归测试中使用固定种子实现可重现性，在探索中使用随机种子增加多样性
- `$urandom` 和 `$urandom_range()` 是 `randomize()` 的轻量化替代，适用于过程代码中的简单随机需求，但不能参与约束求解
- 约束块中的 `foreach` 循环可以对数组的每个元素施加约束：`foreach (data[i]) data[i] inside {[0:255]};`，使约束声明更加简洁

## 与其他概念的关系

- [[verification/concepts/coverage-model|覆盖率模型（Coverage Model）]] — CRV 生成的随机激励触发 Covergroup 采样，覆盖率缺口再反馈指导约束调整，两者构成 CDV 的闭环核心
- [[verification/concepts/uvm-methodology|UVM 验证方法学]] — UVM Sequence 机制与 rand/constraint 深度集成，Sequence Item 是 CRV 的数据载体，Sequencer 调度随机 Sequence 的执行
- [[verification/concepts/testbench-architecture|验证平台架构]] — Agent 的 Sequencer 是 CRV 的执行入口，Scoreboard 和 Monitor 是激励效果的检查点
- [[verification/concepts/systemverilog-assertions|SystemVerilog 断言（SVA）]] — CRV 提供激励多样性，SVA 提供时序正确性检查，两者互为补充各司其职
