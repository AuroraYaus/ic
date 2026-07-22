---
type: concept
aliases:
  - SVA
  - SystemVerilog断言
  - 属性检查
tags:
  - asic
  - verification
  - sva
  - assertions
  - property-checking
source_spec: "IEEE 1800-2023 SystemVerilog LRM Chapter 16 (Assertions); Vijayaraghavan & Ramanathan, A Practical Guide for SystemVerilog Assertions"
---

# SystemVerilog 断言（SystemVerilog Assertions, SVA）

SystemVerilog 断言（SystemVerilog Assertions, SVA）是 IEEE 1800 标准中定义的一套用于描述和验证硬件时序行为的声明式语言。断言不是激励生成机制，而是属性的声明——它描述 "设计应该满足什么条件"，由仿真器或形式验证工具自动检查。SVA 既可以嵌入 RTL 代码（White-Box），也可以放置在接口（Interface）或独立的绑定模块（Bind Module）中对设计进行非侵入式检查（Black/Gray-Box）。

## 原理

### 断言分类与基础语法

SVA 断言分为两类：**即时断言（Immediate Assertions）** 和 **并发断言（Concurrent Assertions）**。即时断言遵循仿真事件调度语义，在过程块（`always`/`initial`/`task`/`function`）内执行，类似于普通的 `if` 语句，仅在当前仿真时刻求值一次。其语法为 `assert (expression) [pass_stmt] [else fail_stmt]`，适用于检查非时序条件，如状态读取后验证 FSM 状态合法码等。并发断言则基于时钟采样，在每个时钟沿对属性表达式求值，其核心语法为 `assert property (property_spec)`。并发断言运行在 Reactive Region 之后、Observed Region 的专用断言调度域中，这种独立于 RTL 执行的调度区域确保断言检查不会干扰设计的仿真行为。

### 属性（Property）与序列（Sequence）

属性（Property）是并发断言的核心构建块，用于描述跨时钟周期的行为约束。一个 Property 可以是一个简单的布尔表达式、一个序列（Sequence），或由多个序列通过逻辑运算符组合而成的复杂表达式。序列（Sequence）描述一组信号在连续时钟周期上的时序关系，基本语法为 `sequence s_name; expr1 ##1 expr2 ##2 expr3; endsequence`，其中 `##N` 是延迟操作符（Delay Operator），表示在第 N 个时钟周期后检查后续表达式。序列可以包含重复操作符——连续重复 `expr [*N]` 表示 expr 连续 N 拍成立，非连续重复 `expr [=N]` 表示 expr 在任意位置出现 N 次（不要求连续），跟随重复 `expr [->N]` 等价于 `(!expr [*0:$] ##1 expr) [=N]`，即 expr 第 N 次出现在序列结束时刻。`$rose(sig)`、`$fell(sig)` 和 `$stable(sig)` 是检测信号边沿和稳态最常用的采样值函数，它们比较当前采样值与前一个采样值之间的变化。

### 蕴含运算符

蕴含（Implication）是 SVA 最强大的运算符之一，用于表达 "如果条件 A 成立，那么属性 B 必须成立" 的因果关系。**交叠蕴含（Overlapped Implication, `|->`）** 表示当先行条件（Antecedent）在当前时钟沿成立时，后续属性（Consequent）在同一时钟沿开始检查；**非交叠蕴含（Non-overlapped Implication, `|=>`）** 等价于 `|-> ##1`，即后续属性从下一个时钟周期开始检查。在典型的接口协议检查场景中，`req |=> ack` 描述了请求信号有效后必须在下一个周期给予应答的时序约束。`disable iff (reset)` 是并发断言的可选复位条件，当 reset 为高时断言不进行检查，防止在复位期间产生虚假的断言失败。

### Bind 语句与断言组织

`bind` 语句是 SVA 实现非侵入式验证的关键机制。通过 `bind target_module assertion_module instance_name (.*)` 语法，可以将外部断言模块的实例绑定到目标 RTL 模块或接口的层次中，断言模块可以访问目标模块的所有内部信号（`.*` 端口连接自动匹配同名信号）。这一机制使得断言代码与 RTL 设计代码物理分离——断言可以放在独立的文件中，由验证工程师维护，而无需修改 RTL 设计文件。在 IP 级和 SoC 级验证中，`bind` 配合 `generate` 可以实现条件化的断言绑定（例如仅在特定配置参数有效时才绑定对应的协议检查器）。

## 关键要点

- 并发断言运行在 Observed Region，采用采样值（Preponed Region 的采样数据），避免仿真调度竞争（Race Condition）
- `$past(expr, N)` 函数返回 expr 在 N 个时钟周期前的采样值，用于跨周期值的比较，是构建 Pipeline 数据一致性断言的常用工具
- `$isunknown(expr)` 用于检测信号中的 X/Z 状态，是设计初始化质量检查的必备断言
- 递归属性（Recursive Property）允许属性调用自身以描述无界延迟行为，如 `property p_check; (start |-> (data_ready [->1])); endproperty`
- `intersect` 操作符要求两个序列在同一时刻开始和结束；`throughout` 操作符要求一个表达式在整个序列持续的每个周期都成立
- SystemVerilog 的 `cover property` 语句用于记录并发断言的成功覆盖情况，与 `assert property` 配合实现属性驱动的功能覆盖率
- 断言中的局部变量（Local Variable）通过 `int v = expr` 在序列中声明，配合 `(expr, v = data)` 模式捕获中间数据值，供后续比较使用
- 在 `bind` 模块中使用 `$assertcontrol` 系统任务可以动态控制全局或特定断言的开关（ON/OFF/KILL），便于在回归测试的特定阶段调整断言行为

## 与其他概念的关系

- [[verification/concepts/formal-verification|形式验证（Formal Verification）]] — SVA 属性是形式验证工具的输入规范语言，BMC 和 Model Checking 直接将 SVA Property 作为证明目标
- [[verification/concepts/uvm-methodology|UVM 验证方法学]] — UVM Interface 中嵌入 SVA 断言进行协议时序检查，`uvm_error` 与 `assert` 的 fail 语句联动
- [[verification/concepts/coverage-model|覆盖率模型（Coverage Model）]] — `cover property` 和 `cover sequence` 提供基于属性的覆盖率，与 Covergroup 互补
- [[verification/concepts/testbench-architecture|验证平台架构]] — SVA 既可以运行在 Testbench 内部的 Checker 中，也可以直接绑定在 DUT 内部，是验证平台检查层的关键组成
