---
type: concept
aliases:
  - Verilog HDL_硬件描述语言
  - Verilog HDL
  - IEEE 1364
  - 硬件描述语言
  - 硬件描述语言（Hardware Description Language）
tags:
  - asic
  - rtl
  - verilog
  - hdl
  - ieee
source_spec: "IEEE 1364-2001 / 1364-2005, Verilog HDL Language Reference Manual; Palnitkar, Verilog HDL: A Guide to Digital Design and Synthesis"
queries: 4
---
# Verilog HDL

Verilog HDL 是最早被工业界广泛采纳的硬件描述语言之一，由 Gateway Design Automation 于 1984 年创建，1990 年进入公共领域，随后由 IEEE 标准化为 IEEE 1364-1995，最后一个纯 Verilog 标准是 IEEE 1364-2005（此后被 IEEE 1800 SystemVerilog 合并）。Verilog 的设计哲学借鉴了 C 语言的语法，使其对软件工程师友好，但其语义是硬件并行的，需要设计者始终在"这是电路"的思维模型下编写代码。

## 原理

### 模块化结构与数据类型

Verilog 的基本设计单元是模块（Module），通过端口（Port）与外界通信。端口可以是 input、output 或 inout（双向）三种方向。模块内部包含组合逻辑和时序逻辑的描述，可以实例化（Instantiation）子模块以构建层次化设计。Verilog 有两类核心数据类型：wire（线网）和 reg（寄存器）。wire 表示组合逻辑的输出或模块端口间的连接，不存储状态，只能被 continuous assign 语句或模块实例的输出驱动；reg 表示存储元素的输出，在 always 块中被赋值，可以保持状态。这一区分是 Verilog 初学者的主要难点——reg 类型既可用于实际的寄存器，也可用于组合逻辑的 always 块输出，关键在于 always 块的敏感列表和赋值方式，而非类型名称本身。SystemVerilog 以 logic 类型统一了这一混淆。

### 赋值语义与综合

Verilog 中最关键的编码差异是阻塞赋值（`=`, Blocking Assignment）与非阻塞赋值（`<=`, Non-Blocking Assignment）的选择。阻塞赋值在仿真时按顺序立即执行，后续语句必须等待当前赋值完成；非阻塞赋值在仿真时先计算右侧表达式（RHS），在 always 块所有语句的 RHS 计算完成后，统一在时间步末尾更新左侧（LHS）。这一差异直接决定了综合结果：**组合逻辑 always 块使用阻塞赋值**（`always @(*)`），**时序逻辑 always 块使用非阻塞赋值**（`always @(posedge clk)`）。混合使用两种赋值在同一个 always 块中是 RTL 编码的大忌，会同时导致仿真与综合语义不一致（Simulation-Synthesis Mismatch），且综合工具通常会报错。阻塞赋值在时序 always 块中会导致意外的串行化，而非阻塞赋值在组合 always 块中可能导致灵敏度列表不完备时产生锁存器推断。

**仿真调度队列与 NBA Region**：IEEE 1364 / IEEE 1800 标准定义了分层事件队列（Stratified Event Queue），每个仿真时间步划分为多个调度区域（Region）：

| Region | 名称 | 执行内容 |
|:---|:---|:---|
| Active | 激活区 | 阻塞赋值 `=`、`$display`、连续赋值 `assign` 的 RHS 计算 |
| Inactive | 非激活区 | `#0` 零延迟事件 |
| **NBA** | **非阻塞更新区** | **`<=` 的左侧（LHS）更新——RHS 已在 Active 区计算完毕** |
| Observed | 观测区 | 并发断言求值 |
| Re-Active | 反应区 | program 块代码执行 |
| Postponed | 推迟区 | `$strobe`、`$monitor` 打印 |

非阻塞赋值（`<=`）的两阶段执行机制是 Verilog 仿真语义的基石：**Active 区**计算所有 `<=` 右侧表达式并暂存，**NBA 区**将所有暂存结果统一更新到左侧。这精确建模了物理 D 触发器的行为——所有触发器在时钟沿同时采样数据输入端，并统一更新输出。如果用时序 always 块中用 `=`（阻塞赋值），当前语句之后的所有读操作将读到"刚写入的新值"而非"当前周期保持的旧值"——仿真波形与硬件行为脱节，综合工具可能合并寄存器。

### 仿真与综合语义差异

仿真（Simulation）和综合（Synthesis）对 Verilog 的解读存在本质差异，这是 RTL 设计者的核心认知。仿真器是一门事件驱动的解释器，遵循 Verilog 标准 LRM 的全部语义，支持所有语法结构，包括 `#delay`、`initial`、`fork/join`、`force/release` 和系统任务 `$display` 等。综合工具则只理解一个"可综合子集（Synthesizable Subset）"，将这些结构映射到具体的硬件资源（触发器、逻辑门、存储器）。不可综合结构在综合时会被忽略或报错。典型不可综合结构包括：initial 块（仅用于测试平台 Testbench）、`#` 时间延迟（硬件无法定义绝对时间延迟）、`fork/join` 并行块（无法映射到同步电路）、`wait` 语句、层次化引用（Hierarchical Reference）等。设计者必须在编写 RTL 代码时就明确区分可综合代码和仿真专用代码，通常通过 `ifdef SYNTHESIS` 宏来分离。generate 语句（generate-for、generate-if）是可综合的，用于参数化地生成重复硬件结构；`define 宏和 parameter 常量则提供代码复用和参数化能力——`define 是文本替换（仿真前预处理），parameter 是编译时常量（可用于模块实例化时的参数重载，且支持 generate 条件选择）。

### 可综合编码与综合推断

综合工具将 RTL 描述映射为工艺库中的标准单元（Standard Cell），其推断行为直接影响最终的面积、延迟和功耗。理解综合推断规则对编写高质量 RTL 至关重要。

**条件分支的综合推断**：`if-else` 语句被综合为优先级 MUX 链——晚出现的条件在前级条件为假时才被评估，产生优先级编码逻辑。`case` 语句（特别是配合 `unique case` 或 `synopsys parallel_case` 指令时）综合为并行的 MUX 树——所有 case 项并行评估，不产生优先级链。关键差异：`if-else` 优先级编码的延迟为 $\mathcal{O}(N)$（N 个分支），而并行 case 的延迟为 $\mathcal{O}(\log N)$。对于互斥的条件应使用 `case`（显式告诉综合工具有且仅有一个分支为真），对于有优先级的条件应使用 `if-else`（如实数优先级编码器）。

**运算符的综合推断**：`+` 运算符被综合为加法器（综合工具从 DesignWare 库中选择 RCA/CLA/CSA 架构，取决于时序约束和位宽）。`*` 运算符被综合为乘法器（取决于位宽和时序约束，可选择 Booth-Wallace 树、阵列乘法器或流水线乘法器结构）。综合工具不会自动将除法器流水线化——`/` 和 `%` 运算符产生较大的纯组合逻辑块，时序难以收敛，通常需要手动实现或使用 DesignWare 流水线除法器 IP。

**存储器推断**：二维数组（`reg [W-1:0] mem [0:DEPTH-1]`）在 read-before-write 或不带输出寄存器时被推断为异步读 SRAM（寄存器堆风格），在 always_ff 中带地址寄存和输入输出寄存时被推断为同步 SRAM。综合工具根据 DEPTH 和 WIDTH 判断使用触发器阵列还是 SRAM 宏单元。

**编码示例**——可综合参数化同步 FIFO 的部分关键逻辑：

```systemverilog
// ============================================================
// 参数化同步 FIFO（Synchronous FIFO）—— 可综合 RTL 实现
// ============================================================
// 功能：带空满标志的同步 FIFO，读写共用同一时钟
//
// ===== 模块端口声明 =====
// #(parameter ...) ：Verilog-2001 ANSI 风格参数声明
//   DEPTH = 16 —— FIFO 深度（存储条目数），默认 16
//   WIDTH = 8  —— 数据位宽（每条目比特数），默认 8
// input  logic ：输入端口，logic 类型（SystemVerilog 统一 wire/reg）
// output logic ：输出端口，logic 类型
// [WIDTH-1:0]  ：位宽声明——WIDTH 位向量，最高位 WIDTH-1，最低位 0
//
module sync_fifo #(
    parameter DEPTH = 16,                         // FIFO 深度（可被实例化时覆盖）
    parameter WIDTH = 8                           // 数据位宽（可被实例化时覆盖）
) (
    input  logic             clk,                 // 时钟（上升沿有效）
    input  logic             rst_n,               // 复位（低电平有效，_n 后缀约定）
    input  logic             wr_en,               // 写使能（1=写入有效）
    input  logic             rd_en,               // 读使能（1=读出有效）
    input  logic [WIDTH-1:0] wr_data,             // 写入数据（WIDTH 位宽）
    output logic [WIDTH-1:0] rd_data,             // 读出数据（WIDTH 位宽）
    output logic             empty,               // 空标志（1=FIFO 为空，不可读）
    output logic             full                 // 满标志（1=FIFO 为满，不可写）
);
    // ===== 内部信号声明 =====
    // mem 二维数组：存储器阵列——WIDTH 位宽，DEPTH 个条目
    // 语法：logic [W-1:0] mem_name [0:DEPTH-1]; —— unpacked 维度在后
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    // $clog2()：系统函数，返回以 2 为底的对数向上取整（Ceiling Log Base 2）
    //   $clog2(16) = 4 —— 需要 4 位二进制编码 0-15
    //   wr_ptr/rd_ptr 位宽为 $clog2(DEPTH)+1 即 5 位，多出的最高位（MSB）
    //   用于区分 FIFO 是"空"还是"满"——当低 4 位相等时：
    //     MSB 相同 → 读写指针完全一致 → 空
    //     MSB 不同 → 写指针比读指针多绕一整圈 → 满
    logic [$clog2(DEPTH):0] wr_ptr, rd_ptr;

    // ===== 进程：时序逻辑 —— 读写指针与数据存储器更新 =====
    //
    // always_ff：SystemVerilog 专用的时序逻辑块
    //   - 强制敏感列表仅含边沿事件（posedge/negedge），不能出现电平敏感信号
    //   - 综合工具会验证输出确实映射到触发器，否则报错
    //
    // @(posedge clk or negedge rst_n)：异步复位 + 时钟上升沿触发的敏感列表
    //   - posedge clk    → 时钟上升沿：每个上升沿触发一次 always_ff 执行
    //   - or negedge rst_n → 异步复位下降沿：rst_n 下降沿立即复位（不等时钟）
    //   - 这种写法综合为带异步复位引脚的 D 触发器（D-FF with async reset）
    //
    // <= ：非阻塞赋值（Non-Blocking Assignment）
    //   - 所有 <= 语句在当前时间步结束时统一更新左侧变量
    //   - 时序逻辑 always_ff 中必须使用 <=，确保所有触发器同时更新
    //   - 错误混用 =（阻塞赋值）会导致综合前后仿真不一致
    always_ff @(posedge clk or negedge rst_n) begin
        // rst_n=0 时：异步复位，所有寄存器清零
        // '0 ：全零填充（自动匹配左侧位宽——wr_ptr 为 5 位 '0 = 5'b00000）
        if (!rst_n) begin
            wr_ptr <= '0;                          // 写指针复位为 0
            rd_ptr <= '0;                          // 读指针复位为 0
        end else begin
            // ===== 写操作 =====
            // wr_en && !full：写使能有效 且 FIFO 未满时执行写操作
            //   - wr_en=1：外部请求写入
            //   - !full=1：FIFO 未满，有空间接收数据
            // wr_ptr[$clog2(DEPTH)-1:0]：取指针的低 $clog2(16)=4 位
            //   作为 SRAM 地址索引——高 1 位（MSB）仅用于空满判断
            if (wr_en && !full) begin
                mem[wr_ptr[$clog2(DEPTH)-1:0]] <= wr_data;  // 写入数据到存储器
                wr_ptr <= wr_ptr + 1'b1;                     // 写指针自增（自动循环——溢出回绕）
            end
            // ===== 读操作 =====
            // rd_en && !empty：读使能有效 且 FIFO 非空时执行读操作
            if (rd_en && !empty) begin
                rd_data <= mem[rd_ptr[$clog2(DEPTH)-1:0]];   // 从存储器读出数据
                rd_ptr <= rd_ptr + 1'b1;                      // 读指针自增（自动循环）
            end
        end
    end

    // ===== 组合逻辑：空满标志生成 =====
    //
    // assign：连续赋值语句（Continuous Assignment）
    //   - 右侧表达式任何信号变化时，立即重新计算并更新左侧
    //   - 等价于组合逻辑——无存储状态
    //   - 被综合为与门、或门等组合逻辑门
    //
    // empty：读写指针完全相等 → FIFO 为空
    //   写指针追上读指针 = 全部被读出
    assign empty = (wr_ptr == rd_ptr);

    // full：写指针比读指针多绕一整圈
    //   判断条件分两部分：
    //   1. 低 $clog2(16)=4 位相等（读写地址相同）
    //   2. 最高位（MSB）不相等（写指针多绕一圈，MSB 取反）
    //   两者同时成立 → FIFO 写满 DEPTH 个条目后追上读指针
    assign full  = (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0])
                 && (wr_ptr[$clog2(DEPTH)] != rd_ptr[$clog2(DEPTH)]);
    //   ^                             ^
    //   低地址位相等                   最高位（圈数标记）不相等
    //   （读到写的位置）               （写比读多绕了一圈）
endmodule
```

### 有符号与无符号运算规则

signed/unsigned 语义是 RTL 设计高频 bug 源——四组规则覆盖全部常见陷阱：

**规则一：类型判定（signedness）**——`wire`/`reg`（及 SV 的 `logic`）默认**无符号**；`signed` 修饰符显式声明有符号；`integer` 是 32 位有符号；字面量分两类：**无基数字面量**（`-8'sd2`、`17`）是有符号整数，**有基数字面量**（`8'hFF`）是无符号。`$signed(expr)`/`$unsigned(expr)` 位模式不变、仅重新解释符号性——且作用于**整个表达式**，不能只转换其中一部分操作数。

**规则二：表达式位宽由表达式自身决定，与赋值目标无关**——表达式位宽等于操作数最大位宽；溢出先发生，之后才扩展/截断到目标位宽：

```verilog
reg [7:0] sum;
reg [3:0] a, b;
assign sum = a + b;                   // ❌ a+b 只有 4 位：溢出先截断，再零扩展到 8 位
assign sum = {1'b0, a} + {1'b0, b};   // ✅ 先扩展操作数，加法按 5 位计算
```

乘法同理：两个 8 位相乘结果是 8 位，正确做法是把操作数先扩展（或声明结果 `logic [15:0] product = a * b;` 时仍须扩展操作数——乘法位宽规则只看操作数）。

**规则三：混合运算整体按无符号处理（unsigned 污染）**——表达式只要有一个无符号操作数，全部操作数按无符号解释，加/减/乘/比较一律如此：

```verilog
logic signed [7:0] s = -8'sd1;        // 1111_1111（-1）
logic        [7:0] u = 8'hFF;         // 1111_1111（255）
s + u                                 // ❌ 无符号加法，结果 254
$signed(u) + s                        // ✅ 有符号加法，结果 -2
```

**规则四：符号扩展、比较与移位**——

```verilog
// 符号扩展 vs 零扩展：窄赋宽时 signed 符号扩展、unsigned 零扩展
logic [15:0] x1 = s;   // s 为 signed 8'hFF → x1 = 16'hFFFF（仍是 -1）
logic [15:0] x2 = u;   // u 为 unsigned 8'hFF → x2 = 16'h00FF（变成 255）

// 比较：signed 操作数 → 有符号比较；混合 → 无符号比较
s > 8'sd0        // ✅ 有符号比较：-1 > 0 为假
s > 8'd0         // ❌ 无符号比较：255 > 0 为真

// 移位：<< / >> 逻辑移位（>> 补 0）；<<< / >>> 算术移位（>>> 补符号位）
// 移位结果位宽 = 左操作数位宽——移位不会扩展位宽
```

**signed 与 unsigned 可以混用——但必须显式控制**。语法上 Verilog 不禁止混用，默认语义是"整体按无符号解释"（规则三）。混用的正确姿势是两步：**先位宽统一（signed 符号扩展、unsigned 零扩展），再符号性统一（整个表达式按一种解释计算）**。关键认识：**加/减的二进制电路与符号性无关**（补码同构）——只要扩展正确，按无符号算出的位模式就是正确答案；signed/unsigned 的真正分歧只有三处：扩展方式（符号 vs 零）、比较解释（有符号 vs 无符号）、溢出/回绕语义。

```verilog
logic        [31:0] base_addr;              // 无符号基地址（接口寄存器）
logic signed [15:0] offset;                 // 有符号偏移（可为负）
logic        [31:0] result_addr;

// ❌ 直接混用：offset 被零扩展成 0x0000FFFC（65532），地址飞了
assign result_addr = base_addr + offset;

// ✅ 正确混用：先符号扩展到公共位宽，再统一按无符号加
//    offset=-4 → 扩展为 32'hFFFFFFFC → base + 0xFFFFFFFC = base - 4
assign result_addr = base_addr + {{16{offset[15]}}, offset};
```

混用的工程准则：（1）**算术混用** → 扩展到位宽统一即可（补码加法同构，无需 $signed() 包装）；（2）**比较混用** → 必须显式 `$signed()` 统一解释，否则真值翻转；（3）**接口边界转换** → 无符号寄存器读入后先 `$signed()` 转有符号再进数据通路；（4）能统一声明就统一声明，混用只发生在边界处。

**下溢陷阱**：计数器递减判断是 unsigned 回绕的经典受害者——`count - 1 > 0` 在 count=0 时回绕成全 1、条件反而为真；改写为 `count > 1` 或使用 signed 计数器。工程建议：（1）需要符号语义的模块统一 `logic signed` 声明；（2）混合表达式显式 `$signed()`/`$unsigned()`；（3）加法/乘法结果位宽显式留足；（4）递减判断改写为纯比较形式。补码与符号扩展的数学基础见 [[concepts/数制|数制]]。

## 关键要点

- **wire/reg 命名具有误导性**：reg 可能综合为组合逻辑输出，关键在于 always 块的敏感性列表和赋值方式，而非类型名称
- **阻塞/非阻塞赋值不可混用**：阻塞赋值（`=`）用于组合 always 块，非阻塞赋值（`<=`）用于时序 always 块；同一 always 块中混用两者是 RTL 严重设计错误，导致仿真-综合不匹配
- **`always @(*)` 自动推断灵敏度**：自动推断组合逻辑的完整灵敏度列表（Verilog-2001 新增），优于手动书写 `always @(a or b or c)` 的易错写法
- **不完备条件导致锁存器推断**：不完备的 if/case（缺少 else/default）在组合 always 块中会导致锁存器（Latch）推断，锁存器对 FPGA/ASIC 设计的时序分析和 DFT 都是有害的
- **generate 语句可综合硬件生成**：generate-for、generate-if、generate-case 用于参数化地创建重复电路结构，但不能在 generate 体内使用不可综合语句
- **`define 宏与 parameter 核心区别**：`define 是预处理宏（文本替换，作用域为整个编译单元），parameter 是模块级编译时常量（局部作用域，可被实例化参数重载 override）
- **仿真与综合语义本质不同**：仿真语义是事件驱动的，所有 always 块在仿真引擎的调度下"伪并行"执行，综合语义则是真实的物理并行
- **复位信号优先判断规则**：复位信号在 Verilog 中通常编写在 always 块的 if 语句中优先判断，异步复位写在灵敏度列表中，同步复位写在 posedge clk 之后的第一个 if 中
- **ANSI C 风格端口声明更简洁**：Verilog-2001 引入了 ANSI C 风格的端口声明，比旧版的端口列表 + 方向声明两步式风格更为简洁
- **signed/unsigned 四组规则是 RTL 高频 bug 源**：表达式位宽与赋值目标无关（溢出先截断后扩展）、混合运算整体无符号（unsigned 污染）、signed 窄赋宽符号扩展而 unsigned 零扩展、下溢回绕让 `count-1>0` 在 count=0 时为真——细节见"有符号与无符号运算规则"章节
- **if-else 优先级链 vs case 并行树**：`if-else` 综合为优先级 MUX 链（延迟 $\mathcal{O}(N)$），`case` 综合为并行 MUX 树（延迟 $\mathcal{O}(\log N)$），互斥条件应使用 `case` 显式消除虚假优先级
- **二维数组推断 SRAM 宏单元**：在 always_ff 中被推断为同步 SRAM 宏单元或触发器阵列，取决于 DEPTH 和 WIDTH 的阈值，`syn_ramstyle` 属性可显式控制映射选择
- **defparam 已弃用应使用命名参数**：模块实例化应使用命名参数关联（`#(.PARAM(value))`），可读性更好且支持参数重载检查
- **tri 类型标识多驱动信号**：Verilog 的 `tri` 类型（等同于 `wire`）用于标识多驱动信号，综合工具在顶层 I/O 端口上使用 `tri` 声明三态总线，内部逻辑禁止多驱动

## 与其他概念的关系

- [[rtl-design/concepts/SystemVerilog|SystemVerilog]] — SV 作为 Verilog 的超集，统一了 wire/reg 为 logic，引入 always_ff/always_comb 等意图显式的 always 块，并增加了 interface、enum 等高级抽象。Verilog 向 SV 的迁移是业界不可逆的趋势——IEEE 1364 自 2005 年后已停止独立更新
- [[rtl-design/concepts/组合逻辑|组合逻辑]] — Verilog 描述组合逻辑的两种方式（continuous assign 与 always @(*)）及其陷阱（锁存器推断）。assign 语句对应连续驱动的线网，always_comb 支持更复杂的条件描述——两者综合结果等价但仿真行为有细微差异（always_comb 对初始化和零延迟事件的处理更符合硬件预期）
- [[rtl-design/concepts/时序逻辑|时序逻辑]] — 非阻塞赋值（`<=`）与 always @(posedge clk) 如何精确描述 D 触发器行为。Verilog 的 reg 类型在时序 always 块中映射到实际的 D-FF，而在组合 always 块中映射到线网输出——这个"类型名称与实际硬件的解耦"是 Verilog 区别于 VHDL 的核心认知难点
- [[rtl-design/concepts/编码风格|RTL 编码风格]] — 基于 Verilog/SV 的可综合编码规范、命名约定（`_i`/`_o`/`_n`）和 lint 规则。编码风格规则的存在理由根植于 Verilog 的语义缺陷——不完整的 if/case 导致锁存器、混合阻塞/非阻塞赋值导致仿真-综合不匹配
- [[concepts/数制|数制]] — 补码是 signed 语义的数学基础：符号扩展保持数值不变、回绕是模 $2^n$ 运算的自然结果，Verilog 的 signed/unsigned 规则正是补码运算在 HDL 层的体现
