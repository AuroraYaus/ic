---
type: concept
aliases:
  - SVA
  - SystemVerilog断言
  - 属性检查
  - Property Specification
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

SVA 断言分为两类：**即时断言（Immediate Assertions）** 和 **并发断言（Concurrent Assertions）**。

即时断言遵循仿真事件调度语义，在过程块（`always`/`initial`/`task`/`function`）内执行，类似于普通的 `if` 语句，仅在当前仿真时刻求值一次。其语法为 `assert (expression) [pass_stmt] [else fail_stmt]`，适用于检查非时序条件。例如，在 FSM 的 always 块中检查状态编码的合法性：

```systemverilog
always @(posedge clk) begin
    state <= next_state;
    // Immediate assertion: state must never be unknown
    assert (!$isunknown(state)) else $error("FSM state is X/Z!");
end
```

并发断言基于时钟采样，在每个时钟沿对属性表达式求值，核心语法为 `assert property (property_spec)`。并发断言运行在 SystemVerilog 调度模型的 Observed Region 中——该区域位于 Reactive Region 之后，专门用于断言评估，确保了断言检查不会干扰设计的仿真行为。其采样规则基于 Preponed Region：断言在每个时间步的最开始（Preponed）对信号值进行采样，然后在整个时间步的事件处理完毕后（Observed）评估属性。

```systemverilog
// Concurrent assertion: req must be followed by ack within 1-3 cycles
assert property (@(posedge clk) disable iff (rst_n)
    $rose(req) |-> ##[1:3] $rose(ack)
) else $error("Handshake protocol violated");
```

### 属性（Property）与序列（Sequence）

属性（Property）是并发断言的核心构建块，用于描述跨时钟周期的行为约束。一个 Property 可以是一个简单的布尔表达式、一个序列（Sequence），或由多个序列通过逻辑运算符（`and`/`or`/`not`）组合而成的复杂表达式。序列（Sequence）描述一组信号在连续时钟周期上的时序关系，基本语法中 `##N` 是延迟操作符（Delay Operator），表示在第 N 个时钟周期后检查后续表达式。

序列的重复操作符是 SVA 最具表达力的特征之一：

| 操作符 | 含义 | 典型场景 |
|:---|:---|:---|
| `expr [*N]` | 连续重复 N 次 | `ready [*3]`：ready 连续 3 拍有效 |
| `expr [*M:N]` | 连续重复 M 到 N 次 | `stall [*0:3]`：0 到 3 拍的 stall 窗口 |
| `expr [=N]` | 非连续重复 N 次 | 数据标记在任意位置出现 N 次 |
| `expr [->N]` | 跟随重复（GoTo） | 等价于 `(!expr [*0:$] ##1 expr) [=N]`，第 N 次出现在序列结束时刻 |

采样值函数是构建时序属性的基本构件：

- `$rose(sig)` — 信号从 0/X/Z 变为 1（正边沿检测）
- `$fell(sig)` — 信号从 1/X/Z 变为 0（负边沿检测）
- `$stable(sig)` — 信号当前采样值等于前一次采样值（无变化）
- `$past(expr, N)` — 返回 N 个时钟周期前的采样值，用于跨周期值的比较
- `$isunknown(expr)` — 检测表达式中是否包含 X 或 Z 位

### 蕴含运算符

蕴含（Implication）是 SVA 表达因果关系的核心机制。**交叠蕴含（Overlapped Implication, `|->`）**：当先行条件（Antecedent）成立时，后续属性（Consequent）在同一时钟沿开始检查。**非交叠蕴含（Non-overlapped Implication, `|=>`）** 等价于 `|-> ##1`，后续属性从下一时钟周期开始。

```systemverilog
// Overlapped: valid asserted → data is non-zero in the same cycle
property p_data_valid;
    @(posedge clk) valid |-> (data != 0);
endproperty

// Non-overlapped: request → grant within 1-4 cycles after request
property p_req_grant;
    @(posedge clk) disable iff (rst_n)
        req |-> ##[1:4] grant;
endproperty
```

`disable iff (expression)` 是并发断言的可选复位条件。当 expression 为真时，断言在当前周期不进行检查，且正在评估中的序列被终止。正确使用 `disable iff` 至关重要：如果复位条件覆盖了合法场景，会导致漏报（False Negative）；如果覆盖不足，复位期间的 X 态会导致误报（False Positive）。

### 递归属性与局部变量

递归属性（Recursive Property）允许属性定义中调用自身，用于描述无界延迟或不定次数的重复行为。其典型模式为 `property_name ( formal_args ); (expr_1) or (expr_2 ##1 property_name(expr_args)); endproperty`。

```systemverilog
// Recursive property: ack must eventually arrive (liveness)
property p_ack_liveness;
    req |-> (ack or (##1 p_ack_liveness));
endproperty
```

局部变量（Local Variable）在序列匹配过程中动态绑定值，用于跨周期数据完整性检查。典型语法为 `(expression, local_var = capture_value)`：

```systemverilog
// Check: when valid is asserted, data must match value 3 cycles later
property p_pipe_data;
    int pipe_val;
    @(posedge clk) (valid, pipe_val = data) |-> ##3 (out_data == pipe_val);
endproperty
```

### Bind 语句与断言组织

`bind` 语句是 SVA 实现非侵入式验证的关键机制。其语法 `bind target_module checker_module instance_name (.*)` 将外部检查器模块绑定到目标 DUT 的层次结构中，`.*` 自动连接同名端口。这使得断言代码与 RTL 设计代码物理分离——断言可以放在独立文件中由验证工程师维护，无需修改 RTL 设计文件。

```systemverilog
// checker_module.sv — separate file, maintained by verification team
module axi_read_checker (
    input logic clk, rst_n,
    input logic arvalid, arready, rvalid, rready,
    input logic [7:0] arid, rid
);
    property p_ar_handshake;
        @(posedge clk) arvalid && arready |-> ##[1:16] rvalid && rready;
    endproperty
    assert property (p_ar_handshake) else $error("AXI read timeout");
endmodule

// Top-level: bind checker to DUT hierarchy
bind dut.axi_sub_system.master_if axi_read_checker checker_inst (.*);
```

在大规模 SoC 中，数百个 bind 语句通过脚本自动生成，每个 bind 对接到一个独立的检查器模块，形成层次化的断言体系。`bind` 配合 `generate` 可实现条件化断言绑定——仅在特定配置或特定 IP 版本有效时才绑定对应的检查器。

### 多时钟断言

SVA 支持在单个属性中使用多个时钟：`@(posedge clk1) expr1 ##1 @(posedge clk2) expr2`。这种多时钟序列在跨时钟域协议检查中非常有用，但实践中需谨慎使用——不同时钟的边沿采样时间点可能引入非确定性。更常见的做法是使用单时钟断言配合同步器设计，而非依赖多时钟 SVA 来检测 CDC 问题。

## 关键要点

- 并发断言运行在 Observed Region，采用 Preponed 的采样值，从根本上避免了仿真调度竞争（Race Condition）——仿真器在时间步开始时对信号值拍照，断言在时间步结束时基于快照进行评估
- `$past(expr, N, @(gating_clk))` 的第三个参数允许指定采样时钟而非默认的断言时钟，在处理多时钟参考场景时非常关键
- `$assertcontrol` 系统任务（`$asserton`/`$assertoff`/`$assertkill`）支持在仿真运行中动态控制断言行为，如复位阶段关闭、初始化完成后打开
- 递归属性虽功能强大但计算开销大——每个递归层级增加一个仿真时间步的评估开销，需要合理设置递归深度上限
- `intersect` 操作符要求两个序列长度严格一致；`throughout` 操作符要求左侧表达式在右侧序列持续的整个周期都为真——两者用于表达精确的时间窗口约束
- `cover property` 语句与 `assert property` 语法完全一致但语义不同：前者记录属性是否至少成功匹配过一次（功能覆盖率），后者检查属性是否恒成立
- SVA 的匹配项（Match Item）语法 `(expr, $display(...))` 允许在属性匹配成功的时刻执行过程语句，常用于打印调试信息或触发覆盖率采样
- 在 `bind` 模块与 DUT 之间：bind 模块可以访问 DUT 的所有内部信号（通过 `.*` 或显式端口），但不能修改 DUT 信号——这是形式验证工具保证断言无副作用的基础

## 与其他概念的关系

- [[verification/concepts/formal-verification|形式验证（Formal Verification）]] — SVA 属性是形式验证工具的输入规范语言，BMC 和 Model Checking 直接将 SVA Property 作为证明/反证目标
- [[verification/concepts/uvm-methodology|UVM 验证方法学]] — UVM Interface 中嵌入 SVA 断言进行协议时序检查，`uvm_error` 与 `assert` 的 fail 语句通过 DPI 联动实现统一的日志管理
- [[verification/concepts/coverage-model|覆盖率模型（Coverage Model）]] — `cover property` 提供基于属性的覆盖率度量，与 Covergroup 的功能覆盖率构成完整的可观测性体系
- [[verification/concepts/testbench-architecture|验证平台架构（Testbench Architecture）]] — SVA 既可以运行在 Testbench 内部的 Checker 中（通过 Interface），也可以直接绑定在 DUT 内部（通过 bind），是验证平台检查层的关键组成
