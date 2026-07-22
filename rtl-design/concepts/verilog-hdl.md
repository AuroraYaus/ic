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
---

# Verilog 硬件描述语言（Verilog HDL）

Verilog HDL 是最早被工业界广泛采纳的硬件描述语言之一，由 Gateway Design Automation 于 1984 年创建，1990 年进入公共领域，随后由 IEEE 标准化为 IEEE 1364-1995，最后一个纯 Verilog 标准是 IEEE 1364-2005（此后被 IEEE 1800 SystemVerilog 合并）。Verilog 的设计哲学借鉴了 C 语言的语法，使其对软件工程师友好，但其语义是硬件并行的，需要设计者始终在"这是电路"的思维模型下编写代码。

## 原理

### 模块化结构与数据类型

Verilog 的基本设计单元是模块（Module），通过端口（Port）与外界通信。端口可以是 input、output 或 inout（双向）三种方向。模块内部包含组合逻辑和时序逻辑的描述，可以实例化（Instantiation）子模块以构建层次化设计。Verilog 有两类核心数据类型：wire（线网）和 reg（寄存器）。wire 表示组合逻辑的输出或模块端口间的连接，不存储状态，只能被 continuous assign 语句或模块实例的输出驱动；reg 表示存储元素的输出，在 always 块中被赋值，可以保持状态。这一区分是 Verilog 初学者的主要难点——reg 类型既可用于实际的寄存器，也可用于组合逻辑的 always 块输出，关键在于 always 块的敏感列表和赋值方式，而非类型名称本身。SystemVerilog 以 logic 类型统一了这一混淆。

### 赋值语义与综合

Verilog 中最关键的编码差异是阻塞赋值（`=`, Blocking Assignment）与非阻塞赋值（`<=`, Non-Blocking Assignment）的选择。阻塞赋值在仿真时按顺序立即执行，后续语句必须等待当前赋值完成；非阻塞赋值在仿真时先计算右侧表达式（RHS），在 always 块所有语句的 RHS 计算完成后，统一在时间步末尾更新左侧（LHS）。这一差异直接决定了综合结果：**组合逻辑 always 块使用阻塞赋值**（`always @(*)`），**时序逻辑 always 块使用非阻塞赋值**（`always @(posedge clk)`）。混合使用两种赋值在同一个 always 块中是 RTL 编码的大忌，会同时导致仿真与综合语义不一致（Simulation-Synthesis Mismatch），且综合工具通常会报错。阻塞赋值在时序 always 块中会导致意外的串行化，而非阻塞赋值在组合 always 块中可能导致灵敏度列表不完备时产生锁存器推断。

### 仿真与综合语义差异

仿真（Simulation）和综合（Synthesis）对 Verilog 的解读存在本质差异，这是 RTL 设计者的核心认知。仿真器是一门事件驱动的解释器，遵循 Verilog 标准 LRM 的全部语义，支持所有语法结构，包括 `#delay`、`initial`、`fork/join`、`force/release` 和系统任务 `$display` 等。综合工具则只理解一个"可综合子集（Synthesizable Subset）"，将这些结构映射到具体的硬件资源（触发器、逻辑门、存储器）。不可综合结构在综合时会被忽略或报错。典型不可综合结构包括：initial 块（仅用于测试平台 Testbench）、`#` 时间延迟（硬件无法定义绝对时间延迟）、`fork/join` 并行块（无法映射到同步电路）、`wait` 语句、层次化引用（Hierarchical Reference）等。设计者必须在编写 RTL 代码时就明确区分可综合代码和仿真专用代码，通常通过 `ifdef SYNTHESIS` 宏来分离。generate 语句（generate-for、generate-if）是可综合的，用于参数化地生成重复硬件结构；`define 宏和 parameter 常量则提供代码复用和参数化能力——`define 是文本替换（仿真前预处理），parameter 是编译时常量（可用于模块实例化时的参数重载，且支持 generate 条件选择）。

### 可综合编码与综合推断

综合工具将 RTL 描述映射为工艺库中的标准单元（Standard Cell），其推断行为直接影响最终的面积、延迟和功耗。理解综合推断规则对编写高质量 RTL 至关重要。

**条件分支的综合推断**：`if-else` 语句被综合为优先级 MUX 链——晚出现的条件在前级条件为假时才被评估，产生优先级编码逻辑。`case` 语句（特别是配合 `unique case` 或 `synopsys parallel_case` 指令时）综合为并行的 MUX 树——所有 case 项并行评估，不产生优先级链。关键差异：`if-else` 优先级编码的延迟为 $\mathcal{O}(N)$（N 个分支），而并行 case 的延迟为 $\mathcal{O}(\log N)$。对于互斥的条件应使用 `case`（显式告诉综合工具有且仅有一个分支为真），对于有优先级的条件应使用 `if-else`（如实数优先级编码器）。

**运算符的综合推断**：`+` 运算符被综合为加法器（综合工具从 DesignWare 库中选择 RCA/CLA/CSA 架构，取决于时序约束和位宽）。`*` 运算符被综合为乘法器（取决于位宽和时序约束，可选择 Booth-Wallace 树、阵列乘法器或流水线乘法器结构）。综合工具不会自动将除法器流水线化——`/` 和 `%` 运算符产生较大的纯组合逻辑块，时序难以收敛，通常需要手动实现或使用 DesignWare 流水线除法器 IP。

**存储器推断**：二维数组（`reg [W-1:0] mem [0:DEPTH-1]`）在 read-before-write 或不带输出寄存器时被推断为异步读 SRAM（寄存器堆风格），在 always_ff 中带地址寄存和输入输出寄存时被推断为同步 SRAM。综合工具根据 DEPTH 和 WIDTH 判断使用触发器阵列还是 SRAM 宏单元。

**编码示例**——可综合参数化同步 FIFO 的部分关键逻辑：

```systemverilog
// 参数化同步 FIFO 的读写指针与空满判断（可综合）
module sync_fifo #(
    parameter DEPTH = 16,
    parameter WIDTH = 8
) (
    input  logic             clk, rst_n,
    input  logic             wr_en, rd_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic [WIDTH-1:0] rd_data,
    output logic             empty, full
);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH):0] wr_ptr, rd_ptr;  // 额外 1 位区分空/满

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr[$clog2(DEPTH)-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (rd_en && !empty) begin
                rd_data <= mem[rd_ptr[$clog2(DEPTH)-1:0]];
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0])
                 && (wr_ptr[$clog2(DEPTH)] != rd_ptr[$clog2(DEPTH)]);
endmodule
```

## 关键要点

- Verilog 的 wire/reg 类型命名具有误导性：reg 可能综合为组合逻辑输出，关键在于 always 块的敏感性列表和赋值方式，而非类型名称
- 阻塞赋值（`=`）用于组合 always 块，非阻塞赋值（`<=`）用于时序 always 块；同一 always 块中混用两者是 RTL 严重设计错误，导致仿真-综合不匹配
- `always @(*)` 自动推断组合逻辑的完整灵敏度列表（Verilog-2001 新增），优于手动书写 `always @(a or b or c)` 的易错写法
- 不完备的 if/case（缺少 else/default）在组合 always 块中会导致锁存器（Latch）推断，锁存器对 FPGA/ASIC 设计的时序分析和 DFT 都是有害的
- generate 语句（generate-for、generate-if、generate-case）是可综合的硬件生成语法，用于参数化地创建重复电路结构，但不能在 generate 体内使用不可综合语句
- `define 是预处理宏（文本替换，作用域为整个编译单元），parameter 是模块级编译时常量（局部作用域，可被实例化参数重载 override）
- 仿真语义是事件驱动的（Event-Driven），所有 always 块在仿真引擎的调度下"伪并行"执行，综合语义则是真实的物理并行
- 复位信号在 Verilog 中通常编写在 always 块的 if 语句中优先判断，异步复位写在灵敏度列表中，同步复位写在 posedge clk 之后的第一个 if 中
- Verilog-2001 引入了 ANSI C 风格的端口声明（模块名后跟 `(input clk, input rst_n, output reg [7:0] data)` ），比旧版的端口列表 + 方向声明两步式风格更为简洁
- `signed` 关键字在 Verilog 中需谨慎使用：wire/reg 默认无符号，算术运算在有/无符号混合时规则复杂，建议始终显式声明 `$signed()` 或使用 `signed` 类型
- `if-else` 综合为优先级 MUX 链（延迟 $\mathcal{O}(N)$），`case` 综合为并行 MUX 树（延迟 $\mathcal{O}(\log N)$）——对于互斥条件应使用 `case` 显式告知综合工具消除虚假优先级
- 二维数组在 always_ff 中被推断为同步 SRAM 宏单元或触发器阵列，取决于 DEPTH 和 WIDTH 的阈值——综合工具的 `syn_ramstyle` 属性可显式控制映射选择
- 模块实例化的 `defparam` 方式已被 IEEE 1800 弃用——应使用命名参数关联（`#(.PARAM(value))`），可读性更好且支持参数重载检查
- Verilog 的 `tri` 类型（等同于 `wire`）用于标识多驱动信号——综合工具在顶层 I/O 端口上使用 `tri` 声明三态总线，内部逻辑禁止多驱动

## 与其他概念的关系

- [[rtl-design/concepts/systemverilog|SystemVerilog]] — SV 作为 Verilog 的超集，统一了 wire/reg 为 logic，引入 always_ff/always_comb 等意图显式的 always 块，并增加了 interface、enum 等高级抽象。Verilog 向 SV 的迁移是业界不可逆的趋势——IEEE 1364 自 2005 年后已停止独立更新
- [[rtl-design/concepts/combinational-logic|组合逻辑]] — Verilog 描述组合逻辑的两种方式（continuous assign 与 always @(*)）及其陷阱（锁存器推断）。assign 语句对应连续驱动的线网，always_comb 支持更复杂的条件描述——两者综合结果等价但仿真行为有细微差异（always_comb 对初始化和零延迟事件的处理更符合硬件预期）
- [[rtl-design/concepts/sequential-logic|时序逻辑]] — 非阻塞赋值（`<=`）与 always @(posedge clk) 如何精确描述 D 触发器行为。Verilog 的 reg 类型在时序 always 块中映射到实际的 D-FF，而在组合 always 块中映射到线网输出——这个"类型名称与实际硬件的解耦"是 Verilog 区别于 VHDL 的核心认知难点
- [[rtl-design/concepts/coding-style|RTL 编码风格]] — 基于 Verilog/SV 的可综合编码规范、命名约定（`_i`/`_o`/`_n`）和 lint 规则。编码风格规则的存在理由根植于 Verilog 的语义陷阱——不完整的 if/case 导致锁存器、混合阻塞/非阻塞赋值导致仿真-综合不匹配
