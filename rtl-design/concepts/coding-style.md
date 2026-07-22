---
type: concept
aliases:
  - RTL编码风格
  - RTL Coding Style
  - 编码规范
  - 可综合RTL
tags:
  - asic
  - rtl
  - coding-style
  - synthesizable
source_spec: "Cummings, SNUG papers on RTL Coding; Sutherland, RTL Modeling with SystemVerilog; IEEE 1800-2017; Synopsys HDL Compiler User Guide"
---

# RTL 编码风格（RTL Coding Style）

RTL 编码风格直接影响综合质量（Quality of Results, QoR）、时序收敛的难度、验证效率和团队协作成本。好的编码风格不是个人偏好的问题，而是直接转化为更小的面积、更高的频率和更少的 bug。综合工具不会"读懂"设计者的意图——它们按照 RTL 的精确描述生成硬件——如果 RTL 描述的是非可综合结构（锁存器、组合环路、多驱动），综合结果将产生功能错误或不可预测的行为。设计者的责任是使用工具能正确理解和优化的构造来描述期望的硬件。

## 原理

### 命名规范与信号约定

统一的命名规范是可维护 RTL 代码的基石。**信号后缀约定**：`_i`（input）、`_o`（output）、`_io`（bidirectional）帮助审阅者快速判断信号方向（在实例化模块内部可见，从调用者角度看）。`_n` 后缀标识低电平有效信号（如 `rst_n`），避免在逻辑中混淆正反极性——所有低电平有效的信号在模块接口上使用 `_n` 后缀，内部使用正逻辑或单独标注。**时钟域前缀**（如 `clk_sys_`、`clk_mem_`）对于多时钟设计至关重要——让 CDC 工具和人眼都能迅速识别跨域信号。参数（`parameter`/`localparam`）使用大写加下划线（如 `DATA_WIDTH`），区别于小写的线网和变量（如 `data_valid`）。

**模块命名**使用 PascalCase 或全小写下划线（`spi_master`），端口排列遵循约定顺序：时钟和复位 -> 配置参数接口 -> 数据输入 -> 数据输出 -> 状态输出。时钟和复位必须是每个模块端口的第一个信号对——工具自动提取时钟和复位树的起点。

### 可综合编码检查清单

可综合 RTL 的编写有硬性约束——违反清单中的任何一项都会导致不可预测的综合行为。**组合逻辑中禁止推断锁存器**：`always_comb`/`always @(*)` 块不完整的条件赋值（if 无 else，case 无 default）导致锁存器推断——综合工具在信号未被赋值时保持上一值，实现为电平敏感锁存器而非边沿触发触发器。锁存器对时序收敛和 DFT 测试都有严重负面影响——`always_comb` 的 SystemVerilog 语义会在仿真中自动展开完整的赋值，但综合工具仍需显式在所有分支覆盖。

**禁止多驱动（Multiple Drivers）**：同一信号不能在多个 `always` 块中被赋值——多个驱动节点直接短路是多驱动冲突的物理含义，综合结果不可预测。多驱动错误通常发生在多个模块或同一个模块的多个 always 块中赋值同一个 wire/reg。**禁止组合环路（Combinational Loop）**：组合逻辑中信号 A 驱动 B 同时 B 驱动 A 的环路——振荡器（在仿真中产生 X 振荡）和不可预测的状态，综合工具通常能检测并报错，但间接环路（通过总线）难以检测。

**敏感列表完整性**：`always @(*)`（Verilog-2001）和 `always_comb`（SystemVerilog）自动推断敏感列表，消除了手工敏感列表不完整的锁存器推断问题。**时序逻辑块中禁止组合赋值**：`always_ff` 块中除 if (reset) 分支外不应出现阻塞赋值（`=`，Verilog），也不应将组合逻辑混入时序块——时序逻辑和组合逻辑的分离是三进程编码的核心。

### FSM 编码模板

FSM 应使用三进程分离模板（状态寄存器 `always_ff` + 次态逻辑 `always_comb` + 输出逻辑 `always_comb`），状态定义使用 `enum` 类型（SystemVerilog）确保类型安全和在波形查看器中的符号显示。`enum` 状态声明隐含独热编码可供综合工具利用。次态逻辑中 case 的每个合法状态必须分配到明确的次态，default 分支指向 IDLE 而非 `current_state`（非法状态恢复）。`unique case` 声明（SystemVerilog）向综合工具指示 case 项是互斥的——工具可消除优先级编码逻辑，减少组合逻辑深度。

### 参数化设计

`parameter` 用于模块实例化时可覆盖的配置（如数据位宽、FIFO 深度、时钟分频比），`localparam` 用于模块内部不可覆盖的派生常量（如 `localparam COUNTER_WIDTH = $clog2(MAX_COUNT+1)`）。`generate` 语句用于基于参数的条件实例化（if-generate）和多模块复制（for-generate）——这是参数化设计的核心工具。过度参数化会增加综合和验证的复杂度——每个参数组合相当于一个独立的设计实例需要验证，参数空间应明确限定经测试的组合。

### CDC 命名与检查约定

多时钟域设计中，跨域信号必须通过命名约定标识：跨域信号的源和目标时钟域在信号名中体现（如 `data_from_clkA_to_clkB`），或使用 SystemVerilog `assert`/`assume` 标注。综合工具对 CDC 信号不加额外优化（如不加缓冲器、不参与逻辑重构）——`ASYNC_REG` 属性标记同步器触发器和 `set_dont_touch` 保护同步器结构不被优化。

### 断言集成

SystemVerilog Assertions (SVA) 应直接嵌入 RTL 模块中——即时断言（Immediate Assertion, `assert (condition)`）用于检测不应发生的内部状态（如 FIFO 上溢、FSM 非法状态）。并发断言（Concurrent Assertion, `assert property (@(posedge clk) ...)`）用于验证跨周期的时序协议（如 valid-ack 握手、请求-授权窗口）。断言嵌入 RTL 的好处：a) 断言随 RTL 传播到综合/门级仿真/形式验证；b) 断言可作为综合和形式验证工具的输入约束。

### Lint 检查项

RTL Lint 工具（SpyGlass Lint、Ascent Lint、Vivado Lint）自动检测编码风格、可综合性、CDC 结构和 DFT 兼容性问题。关键 Lint 规则包括：锁存器推断检测、多驱动检测、组合环路检测、未初始化寄存器检测（上电 X 传播风险）、时钟用作数据检测（时钟信号进入 MUX/D 输入是严重的设计错误）、三态逻辑在非 I/O 端口的使用、异步复位的同步释放检测。所有 Lint 违反必须解决或人工确认为"有意"（Waived with Justification），`lint_clean` 是 RTL Freeze 的条件。

## 关键要点

- 信号命名约定（`_i`/`_o`/`_n` 后缀、时钟域前缀）是代码可维护性的基础——约定一旦确定必须团队全员遵守
- 禁止锁存器（缺 else/default 分支）、禁止多驱动（多 always 块同信号赋值）、禁止组合环路（A->B 且 B->A）是可综合 RTL 的三条铁律
- FSM 使用三进程模板 + SystemVerilog `enum` + `unique case`——是时序清晰、综合友好、Lint 可检查的黄金标准
- `always_comb`/`always_ff`/`always_latch` 意图显式编码优于 Verilog 的通用 `always`——在规范和工具链两层都更安全
- 跨域信号必须命名标识时钟域（`_clkA_clkB`）并标记 ASYNC_REG 同步器触发器——作为 CDC 工具检查的锚点
- 参数化设计使用 `parameter`（可覆盖）+ `localparam`（不可覆盖）+ `generate`（条件/循环实例化）——参数空间须明确限定
- SVA 嵌入 RTL 使断言随设计传播到下游（综合/门级仿真/形式验证）——即时和并发断言覆盖模块内部协议
- Lint 工具检查是 RTL Freeze 的前提——`lint_clean`（零违反或所有违反都有豁免记录）是 RTL 质量的最低标准

## 与其他概念的关系

- [[rtl-design/concepts/fsm-design|FSM 设计]] — 三进程 FSM 模板和状态编码约定（enum/unique case/default 安全恢复）是编码风格的核心子集
- [[rtl-design/concepts/cdc-cross-domain|CDC 设计]] — CDC 命名约定和 ASYNC_REG 属性标记是跨时钟域编码风格的具体要求
- [[rtl-design/concepts/sequential-logic|时序逻辑]] — always_ff 中的同步/异步复位模板和时钟使能编码风格直接影响时序约束的正确标注
- [[rtl-design/concepts/systemverilog|SystemVerilog]] — always_comb/always_ff/enum/unique case 等 SV 构造是提升编码安全性的基础
