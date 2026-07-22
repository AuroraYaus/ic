---
type: concept
aliases:
  - Constrained Random_约束随机验证
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

### 随机变量声明与 rand/randc

SystemVerilog 提供了 `rand` 和 `randc` 两种随机变量修饰符，以及配套的 `rand_mode()` 方法用于动态控制随机状态。

`rand` 声明的变量在每一次 `randomize()` 调用时独立地抽取随机值——各变量之间以及同变量连续随机化之间没有记忆性，同一个值可以连续出现多次。`randc`（Cyclic Random）保证在枚举完所有可能值之前不会重复：求解器维护一个内部循环缓冲器（Cycle Buffer），每次从剩余未抽取过的值中随机选择，直到所有值都被抽过一次后才重新开始新循环。`randc` 适用于需要遍历性覆盖但又不希望编写定向测试的场景。

```systemverilog
class mem_transfer extends uvm_sequence_item;
    rand bit [31:0] addr;
    rand bit [63:0] data;
    randc bit [3:0]  burst_len;  // Cyclic: each length 0-15 tested once per cycle
    rand bit [2:0]   burst_size;

    // Dynamic array with random element count
    rand bit [7:0] byte_enable[];
    constraint data_strobe_size { byte_enable.size() inside {[1:8]}; }
endclass
```

`rand` 支持几乎所有的 SystemVerilog 数据类型：`bit`/`logic` 向量、`integer`、枚举（`enum`）、结构体（`struct`）、联合体（`union`）、动态数组、关联数组和队列。对动态数组而言，`size()` 本身也是内建的随机属性，可以受约束控制。`rand_mode(0)` 可以将特定变量临时从随机化集合中排除（变为固定值），`rand_mode(1)` 恢复其随机属性。

### 约束块语法与语义

约束块（Constraint Block）使用 `constraint c_name { ... }` 定义随机变量的合法空间。求解器将块内所有表达式作为联立方程组（而非顺序语句）求解。

```systemverilog
class axi_transfer extends uvm_sequence_item;
    rand bit [31:0] addr;
    rand bit [7:0]  data[];
    rand bit        is_write;
    rand bit [2:0]  burst_len;

    // Named constraint block: multiple blocks are combined by solver
    constraint c_addr_align {
        addr[1:0] == 2'b00;  // Word-aligned only
    }

    constraint c_data_size {
        data.size() == burst_len + 1;  // Data array matches burst length
    }

    constraint c_write_read_addr {
        if (is_write)
            addr inside {[0 : 32'h0000_7FFF]};      // Write: lower half
        else
            addr inside {[32'h0000_8000 : 32'hFFFF]}; // Read: upper half
    }

    constraint c_no_cross_4k {
        // No burst crosses 4KB boundary
        (addr[11:0] + (burst_len + 1) * (1 << burst_size)) <= 4096;
    }
endclass
```

约束支持多种运算类型：(1) **值域约束**——`data inside {[0:255]};` 使用 `inside` 关键词，支持区间、枚举列表和反转 `!()`；(2) **蕴含约束**——`mode == READ -> addr inside {[0:1023]};` 使用 `->` 表示条件推导（注意与 SVA 蕴含的区分）；(3) **if-else 约束**——与过程代码体验一致但语义是声明式的；(4) **solve-before 约束**——`solve A before B;` 指导求解器在求解 B 之前先确定 A 的值。

### 分布约束详解

`dist` 操作符为随机值赋权重，控制不同值出现的概率。两种权重模式：

- `:=`（Value Weight）：每个列出的值独立获得指定的权重。`[0:3] := 2` 中四个值各得权重 2，总权重 8
- `:/`（Range Weight）：权重均分到范围内的所有值。`[0:3] :/ 8` 中四个值各得权重 2（8/4=2）

```systemverilog
// := vs :/ comparison
x dist { 0 := 1, [1:3] := 2, [4:7] :/ 8 };
// 0:     weight 1    → p = 1/15
// 1-3:   weight 2 each → each p = 2/15
// 4-7:   weight 2 each (8/4=2) → each p = 2/15

// In practice: short bursts more common
burst_len dist {
    0 := 5,        // Single beat: weight 5 each
    [1:3] := 3,    // 2-4 beats: weight 3 each
    [4:7] := 1     // 5-8 beats: weight 1 each (rare)
};
```

分布约束不保证严格按权重产生——求解器是随机的，权重是概率引导而非硬保证。当需要严格的权重控制（如异常注入场景）时，应使用独立的随机变量配合显式条件选择。

### 求解器基础与约束图

约束求解器（Constraint Solver）将随机化问题建模为约束满足问题（CSP, Constraint Satisfaction Problem）。求解过程分为三个核心阶段：

1. **约束图构建**：解析所有活跃约束块的表达式，构建约束图——图中节点为随机变量，有向边代表变量间的约束依赖关系
2. **变量排序**：通过 `solve-before` 指令或启发式自动推理确定变量求解的拓扑顺序
3. **赋值与传播**：按序为每个变量随机赋值，每次赋值后使用约束传播算法（如 AC-3 弧相容算法）剪枝其余变量的候选值域。若赋值造成剩余变量无合法值，回溯到前一个决策点重试

求解器的随机种子决定了整个随机序列：相同的种子 + 相同的随机序列 = 完全可重现的激励——这是回归测试的基本要求。双向约束（Bidirectional Constraints）——`constraint c { A + B == 10; }`——任一变量的赋值自动通过约束传播确定另一变量，这是 CSP 求解器区别于顺序赋值器的核心能力。

### 动态约束控制与软约束

`constraint_mode()` 和 `rand_mode()` 提供运行时的动态约束控制：

- `obj.constraint_mode(0)` — 关闭指定约束块（求解器忽略该块中的约束）
- `obj.constraint_mode(1)` — 重新使能约束块（默认所有约束块使能）
- `obj.rand_mode(0)` — 将变量从随机化集合中排除，保持其当前值不变
- `obj.rand_mode(1)` — 恢复变量的随机属性

软约束（Soft Constraint）使用 `soft` 关键字声明。当软约束与硬约束产生冲突时，求解器自动丢弃软约束以保证硬约束满足。约束优先级从高到低为：

1. **内联约束** `randomize() with { ... }` — 最高优先级
2. **子类硬约束** — 覆盖父类的硬约束
3. **父类硬约束** — 基础定义
4. **软约束** — 最低优先级，冲突时被丢弃

```systemverilog
class base_seq extends uvm_sequence_item;
    rand int size;
    constraint c_size {
        soft size inside {[8:64]};  // Soft: prefer small, can be overridden
    }
endclass

class ext_seq extends base_seq;
    constraint c_size {
        size inside {[64:256]};     // Hard: overrides soft, redefines range
    }
endclass

// At call site:
seq.randomize() with { size == 128; };  // Inline: overrides all
```

### 随机化失败诊断

当约束条件严格到无解时（Over-Constrained），`randomize()` 返回 0。诊断随机化失败是 CRV 验证中的高频痛点——工具特定的调试功能（如 VCS 的 `solve_debug` 或 Cadence 的 `constraint_debug`）可以通过冲突分析找出相互矛盾的约束集合。预防性措施包括：

```systemverilog
if (!item.randomize())
    `uvm_fatal("RAND_FAIL", "Randomization failed — check constraint conflicts")
```

`pre_randomize()` 和 `post_randomize()` 是 `randomize()` 执行流程中的两个标准回调钩子：前者用于设定初始固定值（如 `addr.align = 4`），后者用于计算派生值（如根据随机长度自动计算 CRC 校验值并赋值给 `checksum` 字段）。

## 关键要点

- `rand` 是有放回随机（值可重复），`randc` 是循环无放回（值不重复直到遍历完毕）——前者强调独立性，后者强调遍历性
- 约束求解是 NP 完全问题——商用求解器使用组合了随机搜索和约束传播的混合算法（而非精确求解），因此解的均匀性是近似保证
- `dist` 的 `:=` 和 `:/` 语义差异容易混淆：`[0:255] := 1` 每个值权重 1（总权重 256），`[0:255] :/ 100` 每个值权重 100/256
- `solve-before` 不是可选的装饰性语句——缺少正确的求解顺序可能导致求解器陷入大量回溯甚至随机化失败
- `constraint_mode(0)` 是验证工程师手中灵活但危险的 "万能工具"——关闭关键约束可能导致非法激励流入 DUT 产生虚假 Bug
- `unique` 约束 `constraint c { unique {a, b, c}; }` 要求所有变量取值互不相同，是仲裁器验证确保请求源不重复的标准写法
- `foreach` 在约束块中展开为对数组每个元素的约束：`foreach(data[i]) data[i] inside {[0:255]};` 等价于对每个元素独立施加范围约束
- `$urandom_range(min, max)` 和 `$urandom(seed)` 是 `randomize()` 的轻量化替代——不参与约束求解但在过程代码中快速高效
- 回归测试中 `+ntb_random_seed=N` 命令行参数控制随机种子，固定种子实现重现、随机种子扩大覆盖

## 与其他概念的关系

- [[verification/concepts/coverage-model|覆盖率模型（Coverage Model）]] — Covergroup 定义 "验证什么"，约束随机引擎定义 "激励空间"，两者通过覆盖率缺口反馈驱动约束迭代收敛，构成 CDV 的闭环核心
- [[verification/concepts/uvm-methodology|UVM 验证方法学]] — UVM Sequence 机制与 rand/constraint 深度集成，Sequence Item 是 CRV 的数据载体，Sequencer-Driver 流水线是 CRV 激励注入的执行通道
- [[verification/concepts/testbench-architecture|验证平台架构（Testbench Architecture）]] — Agent 的 Sequencer 是 CRV 的执行入口，Scoreboard 和 Monitor 是激励效果的检查点——激励的随机性必须被观测和检查环完整闭环
- [[verification/concepts/systemverilog-assertions|SystemVerilog 断言（SVA）]] — CRV 提供激励多样性的宽度，SVA 在每个激励下提供时序正确性的深度检查，两者覆盖验证的互补维度
