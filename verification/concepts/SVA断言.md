---
type: concept
aliases:
  - SystemVerilog Assertions_属性检查
  - SystemVerilog断言
  - 属性检查
  - Property Specification
tags:
  - asic
  - verification
  - sva
  - assertions
  - property-checking
queries: 3
source_spec: "IEEE 1800-2023 SystemVerilog LRM Chapter 16 (Assertions); Vijayaraghavan & Ramanathan, A Practical Guide for SystemVerilog Assertions"
---
# SystemVerilog 断言

SystemVerilog 断言（SystemVerilog Assertions, SVA）是 IEEE 1800 标准中定义的一套用于描述和验证硬件时序行为的声明式语言。断言不是激励生成机制，而是属性的声明——它描述 "设计应该满足什么条件"，由仿真器或形式验证工具自动检查。SVA 既可以嵌入 RTL 代码（White-Box），也可以放置在接口（Interface）或独立的绑定模块（Bind Module）中对设计进行非侵入式检查（Black/Gray-Box）。

## 原理

### 断言分类与基础语法

SVA 断言分为两类：**即时断言（Immediate Assertions）** 和 **并发断言（Concurrent Assertions）**。

即时断言遵循仿真事件调度语义，在过程块（`always`/`initial`/`task`/`function`）内执行，类似于普通的 `if` 语句，仅在当前仿真时刻求值一次。其语法为 `assert (expression) [pass_stmt] [else fail_stmt]`，适用于检查非时序条件。例如，在 FSM 的 always 块中检查状态编码的合法性：

```systemverilog
// 过程块（Procedural Block）：在时钟上升沿触发，更新 FSM 状态
always @(posedge clk) begin
    // 非阻塞赋值（Non-blocking Assignment, <=）：
    // 所有 <= 语句在当前时间步结束后统一更新，避免赋值顺序依赖引发的仿真竞争
    state <= next_state;

    // ========== 即时断言（Immediate Assertion）==========
    // 语法：assert (expression) [pass_stmt] [else fail_stmt]
    //
    // $isunknown(expr)：系统函数，检测信号中是否包含 X（未知态）或 Z（高阻态）
    //   - 单比特：X 或 Z 返回 1（真），0 或 1 返回 0（假）
    //   - 多比特：任意位为 X/Z 即返回 1
    //   - 典型用途：FSM 状态寄存器不应出现非法/未初始化的编码
    //
    // ! 逻辑非：$isunknown=1（异常）→ 取反为 0 → assert 条件为假 → 触发 else 分支
    //
    // $error()：打印错误消息但不终止仿真
    //   - 同类系统任务：$warning()（警告）/ $fatal()（立即终止仿真）
    assert (!$isunknown(state)) else $error("FSM state is X/Z!");
end
```

并发断言基于时钟采样，在每个时钟沿对属性表达式求值，核心语法为 `assert property (property_spec)`。并发断言运行在 SystemVerilog 调度模型的 Observed Region 中——该区域位于 Reactive Region 之后，专门用于断言评估，确保了断言检查不会干扰设计的仿真行为。其采样规则基于 Preponed Region：断言在每个时间步的最开始（Preponed）对信号值进行采样，然后在整个时间步的事件处理完毕后（Observed）评估属性。

```systemverilog
// ========== 并发断言（Concurrent Assertion）完整语法拆解 ==========
//
// assert property ( property_spec ) [pass_stmt] [else fail_stmt];
//
// ┌─ @(posedge clk)：时钟边沿说明符
// │   每个 clk 上升沿对信号采样一次，并在 Observed Region 中评估属性
// │   采样发生在 Preponed Region（时间步最开始），保证采样值的稳定性
// │
// ├─ disable iff (rst_n)：异步复位条件
// │   rst_n=0 时：断言暂停检查，正在评估中的序列被终止
// │   rst_n=1 时：断言正常运作
// │   关键设计考量——条件太宽 → 漏报（False Negative）；条件太窄 → 误报（False Positive）
// │
// ├─ $rose(req)：边沿检测函数
// │   检测 req 从 0/X/Z → 1 的跳变（正边沿/上升沿）
// │   同类函数：$fell(sig) 下降沿 / $stable(sig) 无变化 / $changed(sig) 有变化
// │
// ├─ |-> ：交叠蕴含运算符（Overlapped Implication）
// │   先行算子（Antecedent）为真的同一周期，后续算子（Consequent）开始求值
// │   对比 |=> ：非交叠蕴含，等价于 |-> ##1，后续算子从下一周期开始
// │
// └─ ##[1:3] $rose(ack)：延迟范围 + 后续条件
//      ##[min:max] 表示在 min 到 max 个时钟周期范围内等待后续条件成立
//      ##[1:3] = "1、2 或 3 拍后"，只要任一周期成立即通过
//      对比：##3（精确 3 拍）/ ##[1:$]（1 到无限拍，但需注意无界延迟的形式验证成本）
//
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
// ===== 交叠蕴含（Overlapped Implication, |->）=====
// valid 为高的同一周期，data 必须非零
// |-> 的语义：先行条件（valid==1）成立时，后续条件（data!=0）在同一时钟沿求值
property p_data_valid;
    @(posedge clk) valid |-> (data != 0);
    //                    ^              ^
    //                    Antecedent     Consequent
    //                    （先行算子）    （后续算子）
endproperty

// ===== 非交叠蕴含（Non-overlapped Implication, |=>）=====
// req 为高的下一拍开始，1-4 周期内 grant 必须响应
// |=>  等价于  |-> ##1，即"等一拍再开始检查后续条件"
// 注意 disable iff (rst_n) 放在 @(posedge clk) 之后、属性表达式之前
property p_req_grant;
    @(posedge clk) disable iff (rst_n)
        req |-> ##[1:4] grant;
    //  ^        ^         ^
    //  触发条件  延迟范围  被检查信号
    //  （一旦 req=1，在接下来 1-4 周期内 grant 必须为 1）
endproperty
```

`disable iff (expression)` 是并发断言的可选复位条件。当 expression 为真时，断言在当前周期不进行检查，且正在评估中的序列被终止。正确使用 `disable iff` 至关重要：如果复位条件覆盖了合法场景，会导致漏报（False Negative）；如果覆盖不足，复位期间的 X 态会导致误报（False Positive）。

### 递归属性与局部变量

递归属性（Recursive Property）允许属性定义中调用自身，用于描述无界延迟或不定次数的重复行为。其典型模式为 `property_name ( formal_args ); (expr_1) or (expr_2 ##1 property_name(expr_args)); endproperty`。

```systemverilog
// ===== 递归属性（Recursive Property）—— 活性的经典表达 =====
// 语义：req 成立后，ack 要么在当前周期成立，要么等到下个周期再递归检查
//
// 执行逻辑（展开理解）：
//   req |-> (ack or ##1 (ack or ##1 (ack or ##1 ...)))
//   每个周期都有两个出口：ack=1（通过）或继续递归（等待下一拍）
//
// 关键警告：
//   - 递归属性在仿真中每层递归增加一个时钟周期的评估开销
//   - 形式验证中无界递归（没有上限）可能导致工具不终止
//   - 生产代码建议加递归深度限制：
//     property p_ack_liveness(N=16); ... (N==0) or (ack or ##1 p_ack_liveness(N-1));
//   - 仿真器通常有递归深度上限（如 32），超过后会报警告或错误
property p_ack_liveness;
    req |-> (ack or (##1 p_ack_liveness));
    //  ^       ^         ^
    //  触发   出口1    出口2：等一拍，再次调用自己（递归）
    //         ack=1    （如 ack 永远不来，则无限递归）
endproperty
```

局部变量（Local Variable）在序列匹配过程中动态绑定值，用于跨周期数据完整性检查。典型语法为 `(expression, local_var = capture_value)`：

```systemverilog
// ===== 局部变量（Local Variable）—— 跨周期数据完整性检查 =====
// 场景：valid 有效时捕获 data 的值，3 周期后验证 out_data 与捕获值一致
//
// 语法分解：
//   int pipe_val;                          —— 声明局部变量（在 property 内部，非全局）
//   (valid, pipe_val = data)               —— 匹配项（Match Item）语法
//      逗号左边的 valid 是匹配条件（when to capture）
//      逗号右边的赋值是变量绑定（what to capture）
//      两者在同一周期原子执行——valid=1 时，data 的值被"快照"到 pipe_val
//   |-> ##3 (out_data == pipe_val)         —— 3 拍后验证流水线输出值等于原始输入值
//
// 典型用途：流水线数据完整性、FIFO 数据保序性、跨模块数据路由正确性
property p_pipe_data;
    int pipe_val;                                    // 局部变量声明
    @(posedge clk)
    (valid, pipe_val = data)                         // 采样时机：valid 为高时捕获 data
    |->
    ##3 (out_data == pipe_val);                      // 验证时机：3 拍后比对
endproperty
```

### Bind 语句与断言组织

`bind` 语句是 SVA 实现非侵入式验证的关键机制。其语法 `bind target_module checker_module instance_name (.*)` 将外部检查器模块绑定到目标 DUT 的层次结构中，`.*` 自动连接同名端口。这使得断言代码与 RTL 设计代码物理分离——断言可以放在独立文件中由验证工程师维护，无需修改 RTL 设计文件。

```systemverilog
// ===== Bind 检查器模块（Checker Module）=====
// 文件：checker_module.sv（独立文件，由验证团队维护，不修改 RTL 源码）
//
// 端口列表：clk/rst_n + 被检查的 DUT 信号
//   - input 方向：检查器只读信号，不可驱动（保证断言无副作用）
//   - 信号命名与 DUT 内部一致（通过 bind 的 .* 自动连接同名端口）
module axi_read_checker (
    input logic        clk,                             // 时钟
    input logic        rst_n,                           // 复位（低有效）
    input logic        arvalid, arready,                // AXI 读地址通道握手
    input logic        rvalid,  rready,                 // AXI 读数据通道握手
    input logic [7:0]  arid,    rid                     // AXI ID（验证 ID 保序性时可扩展检查）
);
    // 属性定义：读地址握手成功后，读数据握手必须在 1-16 周期内完成
    // arvalid && arready = 一次成功的地址握手（主从双方同时 ready+valid）
    // rvalid && rready   = 一次成功的数据握手
    property p_ar_handshake;
        @(posedge clk) arvalid && arready |-> ##[1:16] rvalid && rready;
        //                   ^ 先行条件             ^ 延迟范围        ^ 后续条件
        //                   （地址握手完成）       （1-16 拍内）    （数据握手完成）
    endproperty

    // 将 property 声明为断言检查
    assert property (p_ar_handshake) else $error("AXI read timeout");
endmodule

// ===== 顶层：将检查器绑定到 DUT 层次结构 =====
// bind <target_module_path> <checker_module> <instance_name> (<port_connections>);
//   - dut.axi_sub_system.master_if：目标模块的层次路径（DUT 内部的 AXI Master 接口）
//   - axi_read_checker：上面定义的检查器模块名
//   - checker_inst：绑定的实例名（在同一目标内唯一即可）
//   - (.*)：自动连接——检查器端口与目标模块内部同名信号自动匹配
//     等效于显式写法：(.clk(clk), .rst_n(rst_n), .arvalid(arvalid), ...)
//     前提：检查器端口名与 DUT 内部信号名完全一致
bind dut.axi_sub_system.master_if axi_read_checker checker_inst (.*);
```

在大规模 SoC 中，数百个 bind 语句通过脚本自动生成，每个 bind 对接到一个独立的检查器模块，形成层次化的断言体系。`bind` 配合 `generate` 可实现条件化断言绑定——仅在特定配置或特定 IP 版本有效时才绑定对应的检查器。

### Checker 编写方法论：端口设计、信号连接与 Bind 层级绑定

Checker（检查器）是 SVA 从"语言特性"走向"工程项目"的桥梁。一个写得好的 Checker 模块可以在不同项目、不同 IP、甚至不同公司之间复用；一个写得不好的 Checker 会把层次路径硬编码进断言正文，让后人花一整天追溯 `bind` 失败的原因。以下从设计哲学、端口规则、信号连接策略、Bind 层级机制、组织复用五个维度展开。

#### 1. Checker 的设计哲学：观察者，而非参与者

Checker 的唯一职责是**被动观察**——读取 DUT 信号，在 Observed Region 评估时序属性，发现违例时报告。它不产生激励、不驱动总线、不修改寄存器。这一原则有三个层面的必要性：

| 层面 | 如果 Checker 能驱动信号会怎样 |
|:---|:---|
| **仿真正确性** | Checker 驱动的值可能与真实激励竞争（race），仿真结果变得不可复现——同一段代码跑两次可能两次结果不同 |
| **形式验证 Soundness** | 形式工具假设断言无副作用；如果 Checker 能改信号，则无法区分"设计 bug 导致的违例"和"Checker 自己制造的问题" |
| **团队协作** | RTL 开发者需要确信"Checker 不会在我的代码里偷偷加逻辑"——这是验证独立性和 RTL 签收信心的基础 |

换言之，Checker 的"只读"约束不是 SystemVerilog 语法的限制，而是验证方法学的自觉约束——你可以违反它，但工程上不应该。

#### 2. 端口方向：不只是"为什么全是 input"

**核心规则**：连接到 DUT 信号的端口，方向必须为 `input`。通向验证辅助逻辑的端口，可以是 `output`。

```systemverilog
// ===== Checker 端口方向的标准模板 =====
module protocol_checker
    // ── 第一组：时钟与复位（input，来自 DUT 或 tb_top）──
    input logic        clk,          // 断言采样时钟
    input logic        rst_n,        // 异步复位（低有效），供 disable iff 使用

    // ── 第二组：被检查的 DUT 协议信号（全部 input）──
    // 命名约定：端口名 == DUT 内部信号名，以利用 bind .* 的自动连接
    input logic        valid,        // 数据有效标志
    input logic        ready,        // 下游就绪标志
    input logic [31:0] data,         // 数据总线
    input logic [ 3:0] keep,         // 字节使能

    // ── 第三组：验证辅助输出（output，可选，不连回 DUT）──
    output logic       assert_fired  // 断言触发标志→传给覆盖率收集器
);
    // 属性定义...
    // assert_fired 由 assertion fail 语句设置，不参与 DUT 信号交互
```

**端口声明的工程决策**：

| 决策点 | 推荐做法 | 反模式 |
|:---|:---|:---|
| 端口数量 | 10-30 个（一个中等协议的数据面信号） | 100+ 端口（Checker 承担了太多职责，应拆分） |
| 信号粒度 | 每个端口对应一个 DUT 逻辑信号 | 合并多个不相关信号到一个宽总线（可读性差） |
| 参数化 | `parameter int DATA_WIDTH = 32` 对可变宽度信号 | 硬编码宽度（导致同一个 IP 的不同配置需要不同 Checker） |
| 命名 | 与 DUT 信号名**完全一致** | "美化"过的缩写（破坏了 `.*` 自动连接） |
| 复位端口 | 每个 Checker 独立声明 `rst_n` | 依赖全局复位（Checker 独立性被破坏，形式验证受阻） |

**Checker 能否驱动 DUT？可以——但用独立的 Force/Driver 模块**

某些验证场景需要在断言失败时强制纠正 DUT 行为（如 ECC 纠错验证、安全关键系统）。正确做法不是让 Checker 驱动输出，而是分离为两个角色：

```systemverilog
// ✅ 正确的关注点分离
module ecc_checker (input ...);  // 只观察，只断言——可独立用于形式验证
module ecc_injector (output ...); // 注入错误、force 纠正——仅在仿真中使用
// 两个模块独立 bind，各司其职
```

#### 3. 信号连接策略：端口连接 vs Interface vs 层次引用

Checker 获取 DUT 信号的三种方式及其工程定位：

```systemverilog
// ===== 方式 A：端口连接 + bind（推荐，非侵入） =====
module fifo_checker (
    input logic clk,
    input logic wr_en, rd_en,      // 端口名与 DUT 信号名完全一致
    input logic full, empty
);
    // ... assertions using wr_en, rd_en, full, empty ...
endmodule
// bind 语句——Checker 文件独立于 DUT 文件
bind dut.data_path.ingress_fifo fifo_checker fchk (.*);

// ===== 方式 B：Interface 连接（UVM 标准做法） =====
// 通过 interface 将一组相关信号打包传递
interface fifo_if (input logic clk);
    logic wr_en, rd_en;
    logic full, empty;
    // protocol assertions 可以直接放在 interface 内部
endinterface
// Checker 接收整个 interface 作为端口
module fifo_checker (fifo_if vif);
    // 使用 vif.wr_en, vif.rd_en ...
endmodule

// ===== 方式 C：层次引用（XMR，仅限调试） =====
module fifo_checker;  // 无端口！信号通过绝对路径访问
    // 硬编码 DUT 层次路径——重构即失效，形式验证不支持
    assert property (@(posedge tb.dut.u_core.clk)
        tb.dut.u_core.wr_en |-> ##[1:3] tb.dut.u_core.full);
endmodule
```

| 方式 | 工程成熟度 | 可移植性 | 形式验证 | 推荐度 |
|:---|:---|:---|:---|:---|
| 端口 + bind | 工业标准 | ✅ 替换 DUT 时只需改 bind 路径 | ✅ | **首选** |
| Interface（UVM） | 工业标准 | ✅ interface 可随 UVM env 复用 | ✅ | 模块级验证首选 |
| 层次引用 XMR | 原型/调试 | ❌ 换项目=重写所有路径 | ❌ | 不推荐 |

**工程建议**：端口方式用于 Checker 独立发布（一个 `.sv` 文件 + 一个 `bind` 脚本即可集成）；Interface 方式用于 UVM 验证环境的 Protocol Checker（Checker 成为 UVM Agent 的一部分，随 Agent 一起复用）。

#### 4. Bind 层级机制：精化时解析、实例/模块两种语义、条件绑定

`bind` 是 SVA 验证基础设施化的核心——它让断言代码从 DUT 中物理分离。但它的层级解析规则是初学者常见错误最密集的区域。

**4.1 两种语义：实例绑定 vs 模块绑定**

```systemverilog
// ===== 实例绑定：精确控制到具体层次路径 =====
// 语法：bind <target_hierarchical_path> <checker_module> <inst> (.*);
// 仅绑定到路径指定的那个实例
bind tb.dut.u_core.axi_if axi_checker chk (.*);

// ===== 模块绑定：覆盖所有同名类型的实例 =====
// 语法：bind <target_module_type_name> <checker_module> <inst> (.*);
// RTL 中**每一个** fifo_32x16 实例都会被自动绑定，无需枚举
bind fifo_32x16 fifo_checker chk (.*);
```

| 场景 | 推荐 | 原因 |
|:---|:---|:---|
| SoC 顶层唯一的 AXI 接口 | 实例绑定 | 精确，无意外副作用 |
| 设计中例化了 200 次的 FIFO 基元 | 模块绑定 | 一次声明覆盖全局 |
| 同一类型但只想检查特定配置下的几例 | 实例绑定 + `generate if` | 条件筛选，精确控制 |
| 第三方 IP 黑盒验证 | 实例绑定 | RTL 内部实例名可能随版本变化 |

**模块绑定的隐藏代价**：如果 `fifo_32x16` 被例化了 300 次，模块绑定会静默生成 300 个 Checker 实例。每个 Checker 中的 `$display`、覆盖率 `sample()`、调试逻辑都会被复制 300 份——仿真日志直接炸掉。生产环境建议在 bind 语句旁加注释标注预期实例数。

**4.2 精化时机（最关键的概念）**

`bind` 在**精化阶段**（Elaboration Phase）完成，在仿真时间 0 之前。这意味着：

- 目标路径必须在精化时**静态存在**——`generate`/`ifdef` 已展开，参数已求值
- `bind` 不能依赖运行时条件（仿真 0 时刻之后的动态层次变更）
- 路径解析失败 = 精化错误，仿真器直接退出，不是运行时警告

**4.3 常见错误与范式**

```systemverilog
// ❌ 错误 1：路径不存在（最常见的精化失败）
bind tb.dut.axi_if.master axi_checker chk (.*);
// master 的实际路径可能是 tb.dut.axi_sub_sys.master
// 修复：用仿真器的层次浏览器（Simvision Design Browser / Verdi nSchema）确认准确路径

// ❌ 错误 2：.* 信号名不匹配——最隐蔽的 bug
// DUT 信号叫 araddr_valid，Checker 端口叫 arvalid
// .* 找不到匹配 → 端口悬空（tie-off to X/Z）→ 断言在 X 态上求值 → 假违例大爆发
// 修复：要么统一命名，要么用显式连接：
bind tb.dut.u_axi axi_checker chk (.arvalid(araddr_valid), .*);

// ❌ 错误 3：generate 块内部的路径索引
// generate for (genvar i=0; i<4; i++) 展开后实例名为 genblk[i].u_fifo
// 直接 bind tb.dut.genblk[0].u_fifo 在部分仿真器中可能不工作
// 修复：用模块绑定代替实例绑定，或在 generate 块内部写 bind
```

**4.4 `bind` + `generate` 条件化绑定**

```systemverilog
// 仅当配置参数满足时才绑定——避免在不适用配置下引入不可达断言
generate
    if (NUM_MASTERS > 1) begin : bind_multi_master_arb
        // 多主场景才需要仲裁检查；单主场景不存在仲裁冲突
        bind arbiter_module arb_checker arb_chk (.*);
    end
    if (ECC_ENABLE) begin : bind_ecc
        // ECC 关闭的配置下，RTL 中不存在 ecc 相关信号——bind 会失败
        bind memory_wrapper ecc_checker ecc_chk (.*);
    end
endgenerate
```

**4.5 调试 bind 的三板斧**

```systemverilog
// 板斧 1：Checker 内部自报家门
module fifo_checker (input logic clk, ...);
    initial begin
        // %m 打印当前实例的完整层次路径
        // 不打印 = bind 未生效；打印了 = 绑定成功 + 知道挂在哪
        $display("[BIND_OK] %m");
    end
endmodule

// 板斧 2：仿真器精化报告
// Questa: vopt -reportbind  →  列出所有 bind 的目标和实例
// VCS:    -report_bind      →  同上（simv 命令行选项）
// Xcelium: -report_bind_instances

// 板斧 3：波形/原理图确认
// Verdi:  nSchema → 双击 DUT 实例 → 查看 Unexpected Hierarchy 下是否出现了 checker_inst
// Simvision: Design Browser → 搜索 checker 实例名
```

#### 5. Checker 的组织与复用策略

编写单个 Checker 不难，难的是在 50 个 IP × 3 种配置的项目中不让 Checker 变成一团乱麻。

**5.1 一个 Checker 对应一个协议**

| 反模式 | 正确模式 |
|:---|:---|
| 一个巨型 `all_checkers.sv` 包含 AXI + AHB + FIFO + ... 全部断言 | `axi_checker.sv`、`ahb_checker.sv`、`fifo_checker.sv` 各自独立 |
| 一个 Checker 检查 AXI 读通道 + 写通道 + 低功耗状态 | 三个 Checker：`axi_read_chk`、`axi_write_chk`、`axi_lp_chk`，按需 bind |

拆分粒度原则：**一个 Checker = 一个可独立验证的协议属性集**。如果你能说"这个 Checker 我只需要给它时钟、复位和 5 个信号就能独立工作"，粒度就对了。

**5.2 参数化 Checker 模板**

```systemverilog
// 参数化 Checker：同一套断言，适配不同数据宽度/深度的实例
module fifo_checker #(
    parameter int DATA_WIDTH = 32,        // 数据位宽（默认 32）
    parameter int DEPTH      = 16,        // FIFO 深度（影响满/空时序假设）
    parameter int THRESHOLD  = 2          // 几乎满/几乎空阈值偏移
) (
    input logic                    clk, rst_n,
    input logic                    wr_en, rd_en,
    input logic [DATA_WIDTH-1:0]   wr_data, rd_data,
    input logic                    full, empty,
    input logic [$clog2(DEPTH)-1:0] wr_count, rd_count
);
    // 断言使用 DATA_WIDTH, DEPTH, THRESHOLD 作为参数
    // 同一个 Checker 通过 bind 绑定到不同参数的 FIFO 实例时，
    // 使用 bind fifo #(.WIDTH(64), .DEPTH(32)) fifo_checker #(.DATA_WIDTH(64), .DEPTH(32)) chk (.*);
endmodule
```

**5.3 Checker 的物理分离层级**

```text
Checkers/                        # 独立的 git 仓库
├── protocols/
│   ├── axi4_chk.sv              # AXI4 协议检查器（可独立发布）
│   ├── ahb5_chk.sv              # AHB5 协议检查器
│   └── fifo_chk.sv              # 通用 FIFO 检查器
├── custom/
│   ├── dma_chk.sv               # 项目特定的 DMA 检查器
│   └── crypto_chk.sv            # 加密引擎检查器
└── bind/
    └── top_bind.sv              # 集中管理所有 bind 语句（按 IP 块分组）
```

完全分离模式下，RTL 团队不需要修改任何 Checker 文件，验证团队不需要访问 RTL 仓库。bind 脚本是两者之间唯一的接口契约——信号名就是 API。

### 多时钟断言

SVA 支持在单个属性中使用多个时钟：`@(posedge clk1) expr1 ##1 @(posedge clk2) expr2`。这种多时钟序列在跨时钟域协议检查中非常有用，但实践中需谨慎使用——不同时钟的边沿采样时间点可能引入非确定性。更常见的做法是使用单时钟断言配合同步器设计，而非依赖多时钟 SVA 来检测 CDC 问题。

### 完整示例：固定优先级仲裁器 — RTL + Checker 端到端

以下以一个 4 请求固定优先级仲裁器为例，展示 RTL 设计与其对应 Checker 的完整协作关系。这个示例覆盖了前面讨论的所有关键概念：`input`/`output` 端口方向设计、`assume property` 输入约束、`assert property` 设计不变量检查、`cover property` 功能覆盖率、以及 `bind` 的非侵入式绑定。

#### RTL 设计：`priority_arbiter`

```systemverilog
/**
 * priority_arbiter: 4 请求固定优先级仲裁器（可综合 RTL）
 *
 * 仲裁策略：req[0] 最高优先级，req[3] 最低优先级。
 * 输出寄存器化（一拍延迟），grant 信号在请求有效后的下一拍给出。
 *
 * 关键时序：
 *   周期 T：   req 到达（req[1]=1）
 *   周期 T+1： gnt 输出（gnt[1]=1，如果无更高优先级请求）
 *
 * @param  N_REQ  请求通道数量（默认 4，可参数化扩展）
 *
 * @note  此仲裁器为固定优先级，不保证公平性——低优先级请求者可能饿死。
 *        需要公平性的场景应使用 Round-Robin 仲裁器。
 */
module priority_arbiter #(
    parameter int N_REQ = 4                     // 请求通道数（参数化，默认 4）
) (
    // ── 时钟与复位 ──
    input  logic                clk,           // 系统时钟
    input  logic                rst_n,         // 异步复位（低有效）

    // ── 仲裁接口 ──
    input  logic [N_REQ-1:0]    req,           // 请求向量（每位对应一个请求者）
    output logic [N_REQ-1:0]    gnt            // 授予向量（每位对应一个授予，one-hot 或全零）
);
    // ===== 仲裁逻辑（组合逻辑）=====
    // 固定优先级编码：从低位（高优先级）向高位（低优先级）扫描
    // 逻辑等价于：gnt[0]=req[0], gnt[1]=req[1] & ~req[0], gnt[2]=req[2] & ~req[1] & ~req[0], ...
    logic [N_REQ-1:0] gnt_comb;                // 组合逻辑计算的中间 grant
    always_comb begin
        gnt_comb = '0;                         // 默认值：无授予（避免 latch 推断）
        for (int i = 0; i < N_REQ; i++) begin
            // 找到第一个（最低位=最高优先级）有效的请求
            if (req[i]) begin
                gnt_comb[i] = 1'b1;            // 授予优先级最高的请求者
                break;                         // 找到后立即退出，不再检查更低优先级
            end
        end
    end

    // ===== 输出寄存器化（时序逻辑）=====
    // grant 信号寄存一拍，避免组合路径过长，改善时序收敛
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gnt <= '0;                         // 复位：清除所有 grant
        end else begin
            gnt <= gnt_comb;                   // 下一拍输出组合仲裁结果
        end
    end
endmodule
```

**RTL 行为要点**：
- 同一拍只有一个 `gnt[i]` 为 1（互斥），或全零（无请求时）
- `gnt[i]=1` 隐含 `req[i]=1`（无虚假授予）
- 优先规则：若 `req[0]=1` 和 `req[2]=1` 同时出现，`gnt[0]=1`，`gnt[2]=0`

#### Checker 设计：`arbiter_checker`

这个 Checker 承担三项职责，对应 `assert`/`assume`/`cover` 三个 SVA 意图方向：

| 意图 | 属性 | 说明 |
|:---|:---|:---|
| **`assert`** — 设计不变量 | 互斥、授予一致性、优先规则 | "这块 RTL 在任何合法输入下都必须满足这些条件" |
| **`assume`** — 输入约束 | 请求在获得授予前保持有效 | "形式验证工具只考虑满足此约束的输入序列" |
| **`cover`** — 覆盖率目标 | 各通道至少一次授予、背靠背授予 | "确认测试激励至少触发过这些场景" |

```systemverilog
/**
 * arbiter_checker: 固定优先级仲裁器的协议检查器
 *
 * 此 Checker 是被动观察者（Passive Observer）——
 * 所有 DUT 信号通过 input 端口读入，不驱动任何 DUT 信号。
 * 唯一的 output 端口 assert_fired 通向验证平台的覆盖率收集器。
 *
 * 检查内容：
 *   - 互斥（Mutual Exclusion）：    同一拍最多一个 grant 有效
 *   - 授予一致性（Grant Consistency）：grant 意味着对应 req 有效
 *   - 优先级规则（Priority Rule）：    高优先级请求存在时，低优先级不应获得授予
 *   - 输入假设（Input Assumption）：   req 在被授予前保持稳定
 *   - 覆盖率（Coverage）：            每个通道至少被授予一次
 *
 * @param  N_REQ  请求通道数量（必须与绑定的 DUT 实例参数一致）
 *
 * @note  此 Checker 中通向 DUT 信号的所有端口均为 input——
 *        这是 Checker 被动观察原则的体现（见"Checker 编写方法论"）。
 * @note  assert_fired 是 output 端口的示范用法——驱动验证辅助逻辑而非 DUT 信号。
 * @see   [[verification/concepts/形式验证|形式验证]]
 * @see   [[verification/concepts/覆盖率模型|覆盖率模型]]
 */
module arbiter_checker #(
    parameter int N_REQ = 4                     // 必须与 DUT 实例的 N_REQ 一致
) (
    // ── 第一组：DUT 信号（全部 input — 被动观察）──
    input  logic                clk,           // 时钟（与 DUT 同一时钟域）
    input  logic                rst_n,         // 复位（低有效）
    input  logic [N_REQ-1:0]    req,           // 请求向量
    input  logic [N_REQ-1:0]    gnt,           // 授予向量

    // ── 第二组：验证辅助输出（output — 通向验证平台而非 DUT）──
    output logic                assert_fired   // 断言违例标志 → 覆盖率收集器/中断聚合
);
    // ============================================================
    // 辅助函数：计算 grant 向量中置位 bit 的数量
    // ============================================================
    /**
     * count_ones: 统计向量中值为 1 的位数（popcount）
     *
     * @param  vec  输入位向量
     * @return      值为 1 的位数（0 ~ N_REQ）
     */
    function automatic int count_ones(input logic [N_REQ-1:0] vec);
        int cnt = 0;
        for (int i = 0; i < N_REQ; i++) cnt += vec[i];
        return cnt;
    endfunction

    // ============================================================
    // 属性 1：互斥（Mutual Exclusion）— assert
    // 同一拍最多一个 grant 位有效（one-hot 或全零）
    // ============================================================
    property p_mutex;
        @(posedge clk) disable iff (!rst_n)    // 复位期间不检查（disable iff 不会误报）
            count_ones(gnt) <= 1;              // grant 中 1 的个数 ≤ 1
    endproperty
    // assert：这条属性是设计不变量——必须恒成立
    assert_mutex: assert property (p_mutex)
        else begin
            $error("[ARB_CHK] Mutual Exclusion violated at %0t: gnt=%b (has %0d bits set)",
                   $time, gnt, count_ones(gnt));
            assert_fired <= 1'b1;              // 通知验证平台：断言已触发
        end

    // ============================================================
    // 属性 2：授予一致性（Grant Consistency）— assert
    // gnt[i]=1 必须隐含 req[i]=1（不能授予一个没有请求的通道）
    // ============================================================
    property p_grant_implies_req(bit [N_REQ-1:0] gnt_bit);
        @(posedge clk) disable iff (!rst_n)
            gnt_bit |-> req;                   // 交叠蕴含：gnt 有效时 req 同拍也必须有效
            // 注意：由于 RTL 将 gnt 寄存了一拍，实际检查的是"gnt 有效 → 对应 req 仍有效"
            // 这就要求 req 在等待期间保持稳定——这正是下面的 p_req_stable 假设保证的
    endproperty
    // 对每个通道生成断言实例
    for (genvar i = 0; i < N_REQ; i++) begin : gen_grant_consistency
        assert_grant_req: assert property (p_grant_implies_req(gnt[i]))
            else $error("[ARB_CHK] Grant without request: gnt[%0d]=1 but req[%0d]=0 at %0t",
                        i, i, $time);
    end

    // ============================================================
    // 属性 3：优先级规则（Priority Rule）— assert
    // 若 gnt[j]=1，则对所有 i < j（更高优先级），req[i] 必须为 0
    // ============================================================
    property p_priority(int gnt_idx, int higher_idx);
        @(posedge clk) disable iff (!rst_n)
            gnt[gnt_idx] |-> !req[higher_idx];
            // 含义：如果低优先级通道 [gnt_idx] 获得了授予，
            //       那么所有更高优先级通道 [higher_idx] 的请求必须为 0
    endproperty
    // 对所有通道对 (i, j) where i < j 生成断言
    for (genvar j = 1; j < N_REQ; j++) begin : gen_priority
        for (genvar i = 0; i < j; i++) begin : gen_priority_pair
            assert_priority: assert property (p_priority(j, i))
                else $error("[ARB_CHK] Priority violated: gnt[%0d]=1 but higher-pri req[%0d]=1 at %0t",
                            j, i, $time);
        end
    end

    // ============================================================
    // 属性 4：请求稳定性假设（Input Assumption）— assume
    // 一旦 req[i] 为 1，在获得 gnt[i]=1 之前必须保持为 1
    // 这是对外部请求者行为的约束——告诉形式验证工具：
    // "只考虑请求者遵守此协议的输入序列，否则你的反例是无效的"
    // ============================================================
    property p_req_stable(int idx);
        @(posedge clk) disable iff (!rst_n)
            // $rose(req[idx]) 检测请求到达的边沿
            // ##1 req[idx] throughout ... 要求 req[idx] 在后续序列中一直为真
            $rose(req[idx]) |-> req[idx] throughout
                // 序列结束条件：gnt[idx] 为真（获得授予，请求可以释放）
                (##[1:$] gnt[idx]);
                //      ^     ^
                //      从下一拍开始  无界延迟——"最终一定会被授予"
                //      注意：形式验证需有界证明（BMC），生产环境可用 ##[1:MAX_WAIT] 替代
    endproperty
    for (genvar i = 0; i < N_REQ; i++) begin : gen_assume_stable
        // assume：不是检查 DUT 是否正确——而是告诉验证工具外部世界的行为规则
        assume_stable_req: assume property (p_req_stable(i));
    end

    // ============================================================
    // 属性 5：覆盖率目标（Coverage）— cover property
    // ============================================================

    // 5a：每个请求通道至少被授予过一次
    property p_coverage_channel_granted(int idx);
        @(posedge clk) disable iff (!rst_n)
            req[idx] ##1 gnt[idx];
            // 请求发出后，下一拍获得授予（RTL 的寄存延迟为 1 拍）
    endproperty
    for (genvar i = 0; i < N_REQ; i++) begin : gen_cover_channel
        // cover：不关心属性是否"恒成立"——只关心"是否至少发生过一次"
        cover_channel: cover property (p_coverage_channel_granted(i));
    end

    // 5b：背靠背（back-to-back）授予——两个不同通道在连续两拍各自获得授予
    // 这个场景测试仲裁器能否在请求密集到达时正确切换通道
    property p_coverage_back_to_back(int first, int second);
        @(posedge clk) disable iff (!rst_n)
            gnt[first] ##1 gnt[second] ##0 (first != second);
            //                    ^^^^
            // ##0 表示"同一拍检查"——first 和 second 通道不同
    endproperty
    cover_btb: cover property (p_coverage_back_to_back(0, 1));

    // 5c：饥饿场景——低优先级通道在有持续高优先级请求的情况下，
    // 最终是否仍能获得授予（取决于仲裁策略，固定优先级仲裁器下此 cover 不可达）
    property p_coverage_starvation;
        @(posedge clk) disable iff (!rst_n)
            // 最高优先级请求持续存在，最低优先级也有请求
            req[0] [*10] ##0 req[N_REQ-1]
            //       ^^ 连续重复 10 拍——模拟"高优先级持续占用"的场景
            |->
            ##[1:$] gnt[N_REQ-1];
            // 最终最低优先级能否获得授予？（固定优先级下——不能，此 cover 预期返回 unreachable）
    endproperty
    cover_starvation: cover property (p_coverage_starvation);
    // 此 cover property 在固定优先级仲裁器下预期结果为 "unreachable"——
    // 这正是 cover 的诊断价值：它揭示了一个设计特性（低优先级可能永远饿死），
    // 而不是设计 bug。如果设计意图是公平仲裁，则这个 unreachable 是 bug。

endmodule
```

#### 顶层集成：`bind` 连接 RTL 与 Checker

```systemverilog
// ===== 顶层集成文件：tb_top.sv =====
// 此文件在 DUT 实例化之后，通过 bind 将 Checker 非侵入式挂载到 DUT 层次中

module tb_top;
    logic clk, rst_n;
    logic [3:0] req, gnt;

    // ── DUT 实例化 ──
    priority_arbiter #(.N_REQ(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .req(req), .gnt(gnt)
    );

    // ── 其他 Testbench 组件（Driver, Monitor, Scoreboard）──
    // ...
endmodule

// ===== bind 命令：将 Checker 绑定到 DUT 实例 =====
// bind <DUT实例路径> <Checker模块名> <Checker实例名> (<端口连接>);
//
// tb_top.dut：            DUT 实例的完整层次路径
// arbiter_checker #(4)：  Checker 模块（参数值与 DUT 一致）
// arb_chk：               Checker 实例名（在此层次内唯一）
// (.*)：                  自动连接——Checker 端口名与 DUT 内部信号名完全一致时自动匹配
//
// 等效显式写法：
//   bind tb_top.dut arbiter_checker #(.N_REQ(4)) arb_chk (
//       .clk(clk), .rst_n(rst_n), .req(req), .gnt(gnt), .assert_fired()
//   );
//   assert_fired 悬空（不连接），Checker 内部通过 else 分支驱动它——仅作验证辅助用途
bind tb_top.dut arbiter_checker #(.N_REQ(4)) arb_chk (.*);
```

#### 示例中的关键设计决策

**端口方向总结**：

| 信号 | 方向 | 连接目标 | 原因 |
|:---|:---|:---|:---|
| `clk, rst_n` | `input` | DUT 时钟/复位 | 与 DUT 同步采样 |
| `req[3:0]` | `input` | DUT 输入信号 | 被动观察——Checker 只看不驱动 |
| `gnt[3:0]` | `input` | DUT 输出信号 | 被动观察——Checker 只看不驱动 |
| `assert_fired` | `output` | 验证平台覆盖率收集器 | **唯一例外**——驱动验证辅助逻辑，不连回 DUT |

**assume vs assert vs cover 的协作闭环**：

```text
assume req 稳定 ──→ 约束输入空间 ──→ 形式验证只考虑合法序列
                                       ↓
assert 互斥/一致/优先 ──→ 检查设计不变量 ──→ 在此空间内证明 property 恒成立
                                       ↓
cover 通道授予/背靠背 ──→ 检查覆盖率目标 ──→ 确认测试激励触达了这些场景
```

三个意图构成完整的验证闭环：**assume 定义规则边界 → assert 在边界内证明正确 → cover 确认我们没有在子空间中盲目测试**。缺少任何一个都会导致验证漏洞：缺 assume → 虚假反例淹没真 bug；缺 assert → 有约束没有检查目标；缺 cover → 不知道激励是否充分。

### cover / assume / assert / property / sequence 的区别与协作

SVA 中的五个核心构造——sequence、property、assert、assume 和 cover——构成了从基础时序描述到完整验证意图的层次体系。它们各自的角色可以类比自然语言：**sequence 是"词语和短语"**（描述时序关系），**property 是"句子"**（表达完整语义），**assert/assume/cover 是"句子的用途"**（声明意图）。

**Sequence（序列）** 是最底层的时序构建块，仅描述"在连续的时钟周期上发生了什么"。一个 sequence 本身没有真值判断——它只是一段时序模式的模板，不声明这段模式是应该发生（assert）、被假定为输入约束（assume），还是用于覆盖率（cover）。Sequence 的核心能力来自其丰富的时序操作符：延迟 `##N`、重复 `[*N]`、非连续重复 `[=N]` 和跟随重复 `[->N]`。Sequence 可以有形式参数（`sequence s(bit sig); ... endsequence`），使其像函数一样可复用。Sequence 可嵌套实例化——一个 sequence 调用另一个 sequence——从而构建层次化的时序描述库。

**Property（属性）** 在 sequence 的基础上增加逻辑运算符（`and`/`or`/`not`/`if-else`）和蕴含关系（`|->`/`|=>`），将时序模式组合成**可判定的行为约束**。Property 的关键区别在于它引入了因果关系——前因（Antecedent）成立时，后果（Consequent）必须满足。Property 也支持 `disable iff` 复位条件，指定在何种条件下属性免于检查。在形式验证中，property 是约束（Constraint）和证明目标（Proof Target）的载体——工具以一个 property 为目标语句，搜索是否存在违反 property 的输入序列。

`cover property`、`assume property` 和 `assert property` 使用相同的 property 语法，但语义完全不同：

| 语句 | 语义 | 等价描述 | 典型使用场景 |
|:---|:---|:---|:---|
| **`assert property`** | 检查属性必须恒成立 | "在所有仿真周期中，property 不得被违反" | 协议合规检查、设计不变量验证 |
| **`assume property`** | 约束输入空间为 property 成立的子集 | "形式验证工具只考虑 property 成立的输入序列" | 形式验证的外部输入假设、模块接口协议假设 |
| **`cover property`** | 检查属性是否至少匹配过一次 | "是否存在至少一个合法的输入序列使 property 成立？" | 功能覆盖率收集、验证意图覆盖检查 |

**Assert（断言）** 是验证工程师最常用的检查语句。它的语义是：在仿真或形式验证中，当 property 被评估时，如果结果不是 "true"（而是 "false" 或 "vacuous"），则报告一次违例（Violation）。在形式验证中，assert 等价于"证明 property 对所有可达状态都成立"。如果工具找到了反例（Counterexample, CEX），则表明设计存在与 property 矛盾的 bug。仿真中，assert 在 property 失败时执行 `else` 分支（`$error`/`$fatal`）。

**Assume（假设）** 与 assert 使用完全相同的 property 语法，但语义截然不同——它不是检查"设计是否正确"，而是**告诉验证工具"外部世界的行为被限制为如下模式"**。在形式验证中，assume 的作用至关重要：没有 assume 约束，形式验证工具会考虑所有可能的输入组合（无约束的自由变量空间），导致虚假反例或状态空间爆炸。Assume 将外部接口的合法协议行为编码为约束，使工具只在合法的输入空间中搜索反例。

典型的 assume 使用场景：假设 AXI Master 不会在 `arvalid` 为低的周期之后立即发送读请求；假设中断 controller 在复位释放后至少等待 10 个周期才产生中断；假设异步 FIFO 的读端时钟频率是写端的 2 倍。这些不是设计不变量——它们是不属于当前验证模块的"环境承诺"。

**Cover（覆盖）** 是 SVA 的第三个意图方向。与 assert 要求 property 恒成立相反，cover 要求 property **至少能找到一个使其成立的场景**。Cover 不检查真伪——它只关心"我们是否曾经达到过某个状态或某个时序模式"。在仿真中，`cover property` 计数每次成功的匹配；在形式验证中，cover 等价于寻找一个满足 property 的见证序列（Witness）——如果工具报告 "unreachable"，意味着**没有任何合法的输入序列能使 cover property 成立**，这通常意味着：
- 可覆盖性 bug：验证环境约束（assume）过于严格，屏蔽了合法的覆盖场景
- 可达性 bug：RTL 设计存在死代码，指定的行为不可能被触发
- 约束 bug：假设（assume）与设计（assert）矛盾，导致合法状态空间为空

**层次关系总结**：

```text
Sequence ──(组合)──> Property ──(声明意图)──> ┌─ assert property  ── 检查恒成立（设计不变量）
                                               ├─ assume property  ── 约束输入空间（环境假设）
                                               └─ cover property   ── 检查可达性（覆盖率目标）
```

五个概念的关系也可类比：sequence 定义了"事件 A 之后 3 拍发生事件 B"的时序模板；property 将之包装为"如果 req 成立，则 ack 必须在 1-3 拍内成立"的完整因果命题；`assert` 说"这个命题必须永远成立"；`assume` 说"外部模块保证这个命题成立，我只管我的模块"；`cover` 说"帮我确认这个命题是不是曾经被触发过、被覆盖到了"。

### assert 与 cover 的空洞真值问题

SVA 中有一个容易被忽视的语义细节：**空洞通过（Vacuous Pass）** 和 **空洞覆盖（Vacuous Cover）**。当蕴含运算符 `|->` 的先行条件（Antecedent）不成立时，属性评估结果为 vacuous pass——即属性形式上通过了，但没有实际意义。`$assertvacuousoff` 系统任务可以使 vacuous pass 不作为 pass 计数，有助于发现激励不足的问题（很多断言看似全部通过，实际上仅因为先行条件从未成立）。

同理，`cover property` 也会因为先行条件未成立而产生 vacuous cover，同样可以通过系统任务控制。在覆盖率驱动的验证流程中，vacuous 问题直接导致覆盖率空洞——我们看到的覆盖率数字可能包含大量"无意义的通过/覆盖"，真实的功能覆盖率远低于报告值。

## SVA 辅助函数与任务

在验证平台中，函数（Function）和任务（Task）经常与 SVA 断言协同工作——函数用于封装可复用的属性辅助逻辑，任务用于断言失败后的调试信息采集。以下示例展示 DOXYGEN 风格的完整注释规范，这是知识库代码必须遵循的标准。

### 函数示例：序列匹配计数器

```systemverilog
/**
 * count_sequence_matches: 统计并发断言在仿真中的匹配次数
 *
 * 该函数封装了 SystemVerilog 断言控制的任务调用模式，
 * 用于读取指定断言的匹配计数，帮助构建覆盖率驱动的验证闭环。
 *
 * 实现原理：
 *   - 调用 $assertcontrol 系统任务读取内部计数器
 *   - 将计数值通过 DPI-C 接口传递给覆盖率数据库
 *   - 返回值为本仿真周期内的新增匹配次数
 *
 * @param  assert_name  断言层次路径（string 类型），如 "tb.dut.checker.p_handshake"
 * @param  reset_count  是否在读取后清零计数器（logic 类型，1=清零，0=保留）
 * @return              本周期新增匹配次数（int 类型，-1 表示断言未找到）
 *
 * @note  该函数为纯组合逻辑，0 仿真时间消耗，可在任何过程块中调用
 * @warning 在形式验证工具中，此函数的行为取决于工具对 $assertcontrol 的支持程度
 * @see    IEEE 1800-2023 Section 20.12（Assertion control tasks）
 */
function automatic int count_sequence_matches(
    input string assert_name,          // 断言的完整层次路径
    input logic  reset_count           // 1=读取后清零，0=累计保留
);
    int match_cnt;                     // 局部变量：存储读取的匹配次数

    // $assertcontrol：系统任务，读取/控制断言状态
    // 注意：此处使用过程化控制，不消耗仿真时间
    if (reset_count) begin
        match_cnt = $assertcontrol(6, assert_name);  // control_type=6: 读取并清零
    end else begin
        match_cnt = $assertcontrol(5, assert_name);  // control_type=5: 只读取不清零
    end

    return match_cnt;                  // 返回匹配次数（-1 = 断言路径无效）
endfunction
```

### 任务示例：断言失败回调处理器

```systemverilog
/**
 * assertion_failure_handler: 断言失败时的调试信息采集任务
 *
 * 当 SVA 断言触发 fail 语句时，调用此任务执行标准化的调试动作序列：
 *   1. 记录当前仿真时间戳
 *   2. 转储 DUT 内部关键信号快照
 *   3. 生成波形数据库的检查点标记
 *   4. 可选：触发自动重放（Replay）以采集更多调试数据
 *
 * 设计考量：
 *   - 本任务为 non-automatic（默认 static），确保多次调用共享状态
 *   - 使用 fork-join_none 启动独立进程，避免阻塞断言 else 分支
 *   - 调试信息写入独立日志文件（不污染仿真主日志）
 *
 * @param  assert_path     触发失败的断言层次路径（string 类型）
 * @param  severity        严重级别（int 类型）: 0=WARNING, 1=ERROR, 2=FATAL
 * @param  capture_signals 需转储波形的时间窗口（int 类型，单位：时钟周期）
 * @param  auto_replay     是否触发自动重放（logic 类型，1=启用）
 *
 * @note  任务消耗仿真时间（内部含 @(posedge clk) 等待），
 *         因此不能从 function 中调用——仅从 always/initial 块或另一 task 中调用
 * @warning 自动重放功能依赖仿真器支持的 save/restore 特性，
 *          在 QuestaSim/VCS/Xcelium 中的实现方式不同，需条件编译适配
 * @see    [[verification/concepts/验证平台架构|验证平台架构]]
 */
task automatic assertion_failure_handler(
    input string assert_path,          // 断言层次路径，如 "tb.top.dut_if.p_data_valid"
    input int    severity,             // 0=WARNING / 1=ERROR / 2=FATAL
    input int    capture_signals,      // 回退采集窗口（拍数）
    input logic  auto_replay           // 1=自动重放失败场景
);
    // ----- 步骤 1：记录时间戳和上下文 -----
    $display("[ASSERT_FAIL] Time=%0t | Path=%s | Severity=%0d",
             $time, assert_path, severity);

    // ----- 步骤 2：根据严重级别执行分级响应 -----
    case (severity)
        0: $warning("Assertion warning: %s", assert_path);    // 警告：仅打印
        1: $error("Assertion error: %s", assert_path);        // 错误：打印 + 计数
        2: $fatal(2, "Assertion fatal: %s", assert_path);     // 致命：立即终止仿真
        default: $error("Unknown severity for: %s", assert_path);
    endcase

    // ----- 步骤 3：启动独立进程采集调试波形 -----
    // fork-join_none：不阻塞当前流程，子进程独立运行
    fork
        begin
            // 在 capture_signals 个周期内逐拍记录关键信号
            repeat (capture_signals) begin
                @(posedge tb.clk);                             // 等待下一个时钟沿
                $fwrite(debug_fd, "T=%0t: state=%b\n",        // 写入调试日志文件
                        $time, tb.dut.state);
            end
        end
    join_none                                                      // 不等待子进程完成

    // ----- 步骤 4：可选自动重放 -----
    if (auto_replay) begin
        // 自动重放（Replay）：保存当前仿真状态，修改激励后重新执行失败窗口
        // 实现依赖具体仿真器，此处仅展示调用框架
        `ifdef VCS
            $save(0);                                            // VCS 保存点
        `elsif QUESTA
            $checkpoint(assert_path);                            // Questa 检查点
        `endif
    end
endtask
```

### DOXYGEN 注释规范要点

在数字IC知识库中，所有 SystemVerilog 函数和任务必须遵循以下 DOXYGEN 风格注释标准：

| 标签 | 用途 | 是否必需 | 示例 |
|:---|:---|:---|:---|
| `@brief` 或首行 | 单行功能描述 | **必需** | `统计并发断言的匹配次数` |
| 空行后的段落 | 详细功能说明（原理、算法、设计考量） | **必需**（≥2 段） | 实现原理 + 使用注意事项 |
| `@param  name` | 参数说明：方向（input/output/ref）、类型、用途 | **必需**（每个参数） | `@param  assert_name  断言层次路径（string 类型）` |
| `@return` | 返回值说明（仅 function） | **必需**（有返回值时） | `@return  本周期新增匹配次数（int，-1=失败）` |
| `@note` | 补充说明/使用提示 | 推荐 | 仿真时间消耗、可调用上下文等 |
| `@warning` | 注意事项/限制条件 | 推荐 | 工具依赖性、跨平台行为差异等 |
| `@see` | 相关参考（wikilink 或标准章节） | 推荐 | `@see IEEE 1800-2023 Section 20.12` |

**与非知识库代码的关键区别**：
- 注释使用**中文**描述参数和功能（知识库面向中文读者）
- 每个关键语句有**独立的行内注释**，而非仅一段笼统说明
- `@see` 标签中使用 Obsidian wikilink 格式链接到知识库内其他概念

### 握手协议断言示例

**SVA 断言的两大分类：**

**即时断言（Immediate Assertion）** 遵循仿真事件调度语义，在过程块（`always`/`initial`/`task`/`function`）内执行，仅在当前仿真时刻求值一次。语法为 `assert (expression) [pass_stmt] [else fail_stmt]`，适用于非时序条件检查。

**并发断言（Concurrent Assertion）** 基于时钟采样，在每个时钟沿对属性表达式求值，核心语法为 `assert property (property_spec)`。并发断言运行在 SystemVerilog 调度模型的 Observed Region 中，采样取自 Preponed Region——这从根本上避免了仿真调度竞争。

**握手协议（Handshake Protocol）断言 —— 完整示例：**

以下以一个标准的 Valid-Ready 握手协议为例，展示从信号定义到完整断言体系的构建过程。

**信号定义（标准 Valid-Ready 握手）：**
- `valid`：发送方有数据待发送（高有效）
- `ready`：接收方准备好接收数据（高有效）
- `data`：传输的数据（`valid && ready` 同时为高时有效）
- 一次成功的握手 = `valid && ready` 在同一时钟沿为真

```systemverilog
// ===== 握手协议 SVA 断言完整示例 =====
module handshake_checker (
    input logic        clk,               // 采样时钟
    input logic        rst_n,             // 异步复位（低有效）
    input logic        valid,             // 发送方有效标志
    input logic        ready,             // 接收方就绪标志
    input logic [31:0] data               // 数据总线
);
    // ============================================================
    // 断言 1：数据稳定性 —— valid 有效且 ready 未就绪时，数据必须保持
    // ============================================================
    // $rose(valid)：正边沿检测——valid 从 0→1 的跳变
    // ##1 valid throughout (##[1:$] ready):
    //   valid 从下一拍开始在 ready 为高之前必须一直为真（throughout 操作符）
    // ##1 $stable(data): 在 valid 稳定的每一拍，data 也必须保持稳定
    //   注意 $stable 参数列表——如果只写 $stable，不对应任何信号，会报错
    property p_data_stable;
        @(posedge clk) disable iff (!rst_n)
            $rose(valid) |-> valid throughout (##[1:$] ready)
                            ##0 $stable(data);
                            //  ^^^^
                            // ##0: 在同一拍检查——valid 稳定期间 data 每拍都必须保持
    endproperty
    assert property (p_data_stable)
        else $error("Data changed while valid=1 and ready=0");

    // ============================================================
    // 断言 2：握手完成后 valid 必须释放 —— 防止重复传输
    // ============================================================
    // valid && ready: 一次成功的握手
    // |=>: 非交叠蕴含——下一拍检查
    // !valid: 下一拍 valid 必须为低
    //   含义：握手成功后，发送方必须置低 valid（不能连续发送而未刷新数据）
    property p_handshake_release;
        @(posedge clk) disable iff (!rst_n)
            valid && ready |=> !valid;
    endproperty
    assert property (p_handshake_release)
        else $error("valid not released after handshake");

    // ============================================================
    // 断言 3：Ready 超时检查 —— 避免无限等待
    // ============================================================
    // ##[1:MAX_WAIT] ready: 1 到 MAX_WAIT 周期内 ready 必须响应
    //   延迟范围上限是避免仿真死锁的关键——不加上限时仿真永远等待
    localparam int MAX_WAIT = 16;          // 最多等待 16 拍
    property p_ready_timeout;
        @(posedge clk) disable iff (!rst_n)
            valid |-> ##[1:MAX_WAIT] ready;
    endproperty
    assert property (p_ready_timeout)
        else $error("Ready timeout: valid asserted for >%0d cycles", MAX_WAIT);

    // ============================================================
    // 断言 4：Valid 不应被丢弃 —— Liveness 属性
    // ============================================================
    // 如果 valid 已经为高，ready 必须在有限时间内响应
    // $rose(valid) ##1 !ready [*]：连续多拍的 !ready
    // |-> ##[1:MAX_WAIT] ready：必须在 MAX_WAIT 周期内获得 ready 响应
    property p_valid_not_dropped;
        @(posedge clk) disable iff (!rst_n)
            $rose(valid) |-> strong(##[1:MAX_WAIT] ready);
            //                  ^^^^^
            // strong(): 强属性——要求序列必须最终匹配（不允许截断）
            // 对比 weak()（默认）：仿真结束时序列未完成也算通过
    endproperty
    assert property (p_valid_not_dropped)
        else $error("Valid was asserted but never got ready within %0d cycles", MAX_WAIT);

    // ============================================================
    // 覆盖属性：握手覆盖率收集
    // ============================================================
    // cover property: 检查此时序场景是否至少发生过一次
    //   back-to-back handshake: 连续两拍握手——测试最大吞吐量场景
    property p_back_to_back;
        @(posedge clk) disable iff (!rst_n)
            valid && ready ##1 valid && ready;
    endproperty
    cover property (p_back_to_back);

    //   长等待后握手成功：测试 Ready 在接近超时边界时才响应的 corner case
    property p_long_wait;
        @(posedge clk) disable iff (!rst_n)
            $rose(valid) ##[MAX_WAIT-2:MAX_WAIT] ready;
    endproperty
    cover property (p_long_wait);

endmodule
```

**握手协议断言的关键设计考量：**

| 考量 | 说明 | 建议 |
|:---|:---|:---|
| **`disable iff` 条件** | 复位期间断言免于检查，避免 X 态误报 | 使用异步复位信号作为 disable 条件 |
| **延迟上限** | 无界延迟（`##[1:$]`）在仿真中是安全的但在形式验证中可能导致不终止 | 生产代码始终使用有界延迟 `##[1:MAX]` |
| **`strong()` vs `weak()`** | `weak()` 在仿真结束时截断也通过——可能导致假通过 | 活性（Liveness）属性用 `strong()`，安全性（Safety）属性用默认 `weak()` |
| **`$stable()` 检查** | 握手协议中数据在 Valid 有效期间不应变化 | 必须是 `$stable(data)` 而非 `$stable`（无参） |
| **`$past()` 跨周期引用** | 用于验证 pipelined 握手中的数据保持 | `$past(data, N)` 返回 N 拍前的采样值 |

**从简单到复杂的 SVA 进阶路径：**

1. **基础**：`assert (expression)` 即时断言——检查当前时刻的简单条件
2. **并发**：`assert property (@(posedge clk) expr)` 并发断言——单时钟沿的单周期检查
3. **时序**：`|-> ##N` 蕴含 + 延迟——描述跨周期的因果关系
4. **协议**：`##[M:N]` + `throughout` + `intersect`——描述完整的协议时序窗口
5. **活性**：`strong(##[1:$])` + 递归属性——描述 "最终必然发生" 的活性条件
6. **系统**：`bind` + `assume` + `cover`——构建完整的验证检查器体系

## 关键要点

- **Observed Region + Preponed 采样消除竞争**：并发断言在 Observed Region 评估，采样取自 Preponed Region（时间步最开始的信号快照），从根本上避免了仿真调度竞争（Race Condition）
- **`$past()` 第三参数指定门控时钟**：`$past(expr, N, @(gating_clk))` 允许使用独立时钟而非默认断言时钟作为采样参考，多时钟域场景的关键技巧
- **`$assertcontrol` 运行时动态开关**：`$asserton`/`$assertoff`/`$assertkill` 支持仿真中按阶段控制断言——复位期间关闭、初始化完成后打开，避免无效报错
- **递归属性需要深度上限**：每个递归层级增加一个仿真时间步的评估开销，生产代码建议显式传入深度参数，防止仿真器超限或形式验证不终止
- **`intersect` 严格等长，`throughout` 全程覆盖**：`intersect` 要求两序列长度精确一致（否则失败），`throughout` 要求左侧表达式在右侧序列持续的整个周期都为真——两者用于精确时间窗口约束
- **`cover property` 与 `assert property` 语法相同，语义对立**：前者问"这个场景出现过吗？"（功能覆盖率），后者问"这个属性永远成立吗？"（设计正确性）
- **Match Item 在匹配时刻执行过程语句**：`(expr, $display(...))` 在属性匹配成功的同一时刻触发，用于调试打印或覆盖率采样，不影响属性真值
- **Bind 模块只读不写 DUT**：通过 `.*` 或显式端口可访问 DUT 全部内部信号，但不能驱动任何值——这是形式验证保证断言无副作用的基础

- **`assume` 仿真与形式语义分裂**：仿真中 `assume` 行为等同于 `assert`（被动检查），形式验证中变为空间约束（主动剪枝）——需要理解同一段代码在两种环境下的双重语义
- **`cover property` 与 Covergroup 互补而非替代**：前者测量"时序模式是否出现过"，后者统计"信号取值分布是否均匀"——两者共同构成完整的覆盖率度量体系
- **Vacuous Pass 是验证质量的首要杀手**：激励从未触发先行条件时，所有 assert 通过统计都是虚假的——`$assertvacuousoff` 和覆盖率交叉检查是发现空洞的关键手段
- **`assume` 将形式验证搜索空间从"宇宙"缩减到"太阳系"**：无 assume 时输入空间为 2^N（N=自由变量总位数），合理的 assume 约束使深度属性证明成为可能
- **跨时钟域 assume 比 assert 更危险**：assume 约束若与真实硬件行为不符，会将形式验证导向不存在的搜索子空间——导致"证明通过但硅片失败"
- **CDV 方法论 = cover property + Covergroup cross 同时 100%**：`cover property` 确认"到达过"，Covergroup cross 确认"遍历充分"，两者缺一不可才构成验证完成

## 与其他概念的关系

- [[verification/concepts/形式验证|形式验证（Formal Verification）]] — SVA 属性是形式验证工具的输入规范语言，BMC 和 Model Checking 直接将 SVA Property 作为证明/反证目标
- [[verification/concepts/UVM方法学|UVM 验证方法学]] — UVM Interface 中嵌入 SVA 断言进行协议时序检查，`uvm_error` 与 `assert` 的 fail 语句通过 DPI 联动实现统一的日志管理
- [[verification/concepts/覆盖率模型|覆盖率模型（Coverage Model）]] — `cover property` 提供基于属性的覆盖率度量，与 Covergroup 的功能覆盖率构成完整的可观测性体系
- [[verification/concepts/验证平台架构|验证平台架构（Testbench Architecture）]] — SVA 既可以运行在 Testbench 内部的 Checker 中（通过 Interface），也可以直接绑定在 DUT 内部（通过 bind），是验证平台检查层的关键组成
