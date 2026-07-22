---
type: concept
aliases:
  - SystemVerilog
  - SV
  - IEEE 1800
  - 系统Verilog
tags:
  - asic
  - rtl
  - systemverilog
  - hdl
  - ieee
source_spec: "IEEE 1800-2017, SystemVerilog Language Reference Manual; Sutherland, RTL Modeling with SystemVerilog"
---

# SystemVerilog（SystemVerilog, SV）

SystemVerilog 是 Verilog HDL 的增强超集，由 Accellera 主导开发，2005 年被 IEEE 标准化为 IEEE 1800-2005（取代了 IEEE 1364 Verilog 标准），最新版为 IEEE 1800-2017。SystemVerilog 不仅统一了硬件描述（RTL）和硬件验证（Verification）两大领域，还引入了大量改善设计意图表达、降低编码错误和提高仿真效率的语言特性。对 RTL 设计而言，SV 将 Verilog 的 wire/reg 概念统一为 logic，引入了意图显式的 always_ff、always_comb 和 always_latch 块，补充了 interface、enum、struct、union、package 等高级抽象，使硬件设计代码的可读性、可维护性和 lint 检出率大幅提升。几乎所有现代 ASIC 和 FPGA 项目的 RTL 编码均已迁移到 SystemVerilog 可综合子集。

## 原理

### logic 类型与 wire/reg 的统一

Verilog 最令人困惑的设计缺陷之一是 wire 和 reg 的类型名称与实际硬件行为不一致——命名暗示 reg 是寄存器输出，但实际上组合逻辑的 always 块输出也必须声明为 reg。SystemVerilog 引入了 **logic** 类型（四值：0、1、X、Z），语义上表示"任意逻辑信号"，可以在 continuous assign、always 块和模块端口上统一使用，编译器根据上下文自动判断行为。logic 变量的关键语义是：**一个 logic 变量只能被一个源驱动**（即单驱动 Single-Driver 约束）。当信号需要多驱动场景时（如总线仲裁、三态门），必须使用 wire 或 tri 类型。这一设计从根本上消除了 wire/reg 的语义混乱，使初学者的学习曲线大幅平滑，也使 lint 工具（如 SpyGlass、Verilator）更容易检测多驱动冲突。logic 类型的另一个优势是默认值行为：logic 变量默认值为 X（未知），而非 Verilog reg 的 X 和 wire 的 Z，仿真时更容易暴露未初始化的设计错误。

### 意图显式的 always 块

SystemVerilog 引入了三个专用的 always 块关键字来替代通用的 `always`，每一类关键字都附带编译时语义检查：

- **`always_ff`**（Flip-Flop）：用于描述时序逻辑（触发器/D-FF），强制要求灵敏度列表包含且仅包含 `posedge` 或 `negedge`，综合工具会验证 always_ff 的输出确实映射到了触发器，若推断出非触发器结构则报错。
- **`always_comb`**（Combinational）：用于描述组合逻辑，自动推断完整的灵敏度列表（无需手动书写 `@(*)`），在仿真零时刻执行一次以计算初始值，并自动禁止内部变量被同一信号赋值（避免 Verilog 中 always @(*) 的仿真竞争）。如果 always_comb 的代码路径不完整（如 if 无 else、case 无 default），综合工具会明确报告锁存器推断警告。
- **`always_latch`**（Latch）：用于有意设计的锁存器（如门控时钟产生电路），强制要求灵敏度列表为电平敏感信号，缺少此关键字时综合工具通常会对意外锁存器发出 lint 警告。

### interface 与 modport

传统 Verilog 中，模块互联需要逐个声明端口连接线，当总线位宽大、信号数量多时（如 AHB、AXI 总线可能包含数百个信号），端口列表声明冗长且极易出错——增加一个信号需要修改所有经过该总线的模块端口列表。SystemVerilog 的 **interface** 将相关信号打包为一个可复用的逻辑组，模块只需在端口列表中声明一个 interface 实例即可接入整个总线。**modport** 是 interface 的方向限定（Direction Qualifier），为同一个 interface 中的信号定义不同模块视角的方向（master/slave/monitor），编译时即可检查方向错误。interface 还支持参数化（parameterized interface）和嵌套（nested interface），配合 clocking block 可以精确控制时钟域边界的时序采样。

### enum、struct、union 与 package

**enum**（枚举类型）将状态机的状态编码从裸整数提升为命名常量，提高可读性并允许综合工具进行最优编码选择。**struct**（结构体）将相关信号打包为单一类型，便于总线数据的总线级操作，如 `struct packed { logic [7:0] addr; logic [31:0] data; } mem_cmd_t` 可在单周期内作为 40 位向量整体赋值和比较。**union**（联合体）允许同一存储空间以不同方式解释位模式，常用于寄存器位域重映射。**package** 将公用的类型定义、parameter、function 和 task 封装为命名空间，通过 `import my_pkg::*` 导入，替代了 Verilog 中 `include 头文件的全局污染问题。package 支持选择性导入（如 `import my_pkg::my_type`）和通配符导入，并提供了编译单元级别的封装隔离。

### DPI（Direct Programming Interface）

DPI 是 SystemVerilog 与 C/C++ 函数双向调用的标准接口。通过 `import "DPI-C" function int my_func(input int a);` 声明，SystemVerilog 代码可以直接调用 C 函数；通过 `export "DPI-C" function my_sv_func;` 声明，C 代码可以回调 SystemVerilog 函数。DPI 是构建仿真模型（如 ISS、Bus Functional Model）、参考模型（Reference Model）和 co-simulation 环境的核心桥梁，使 UVM 验证环境可以复用 C/C++ 黄金模型。

## 关键要点

- logic 类型统一了 wire/reg，默认单驱动约束，多驱动场景仍需使用 wire 或 tri；logic 默认值为 X，便于仿真时暴露未初始化信号
- always_ff/always_comb/always_latch 提供了编译时语义校验，从语法层面锁存器推断、敏感列表不全等 Verilog 常见错误已被消除
- interface + modport 将 RTL 模块互联从信号级抽象提升到总线级，大幅降低端口列表维护成本，减少连线错误
- enum 提供类型安全的状态机编码，综合工具可据此自动选择最优编码（二进制/Gray/独热）
- struct packed 允许将复合数据结构视为位向量进行整体操作，尤其适合总线协议和寄存器定义
- package 替代 `include 的全局宏污染，提供命名空间级别的封装和选择性导入
- 可综合子集排除了 class、virtual interface、mailbox 等验证专用结构，RTL 设计者需明确区分设计与验证的语言边界
- DPI 将 SystemVerilog 仿真与 C/C++ 参考模型连接，是验证环境的关键基础设施，但 DPI 代码不可综合
- `unique case` 和 `priority case` 提供并行/优先级 case 的语法声明，综合工具可据此优化逻辑，且仿真时可检测违反断言（Violation）
- `$clog2()` 是 RTL 设计中计算位宽的必备系统函数，替代手动 `define 宏计算，避免了整数对数的舍入错误

## 与其他概念的关系

- [[rtl-design/concepts/verilog-hdl|Verilog HDL]] — SystemVerilog 作为 Verilog 的超集，对比 wire/reg 与 logic、always 与 always_ff/always_comb 的核心差异
- [[rtl-design/concepts/coding-style|RTL 编码风格]] — 基于 SystemVerilog 的可综合编码规范，包括 always_ff 模板、interface 使用约定、package 组织规范
- [[rtl-design/concepts/sequential-logic|时序逻辑]] — always_ff 如何精确描述 D 触发器、时钟使能、复位策略和时钟门控
- [[rtl-design/concepts/fsm-design|状态机设计]] — 使用 enum 和 always_comb/always_ff 三进程模板实现 Moore/Mealy FSM
