---
type: concept
aliases:
  - RTL编码风格
  - RTL Coding Style
  - 可综合编码规范
tags:
  - asic
  - rtl
  - coding-style
  - best-practices
source_spec: "Sutherland, RTL Modeling with SystemVerilog; Cummings SNUG papers on FSM and CDC coding"
---

# RTL 编码风格（RTL Coding Style）

RTL 编码风格直接影响综合质量（Quality of Results, QoR）、时序收敛的难度、验证效率和团队协作成本。好的编码风格不是个人偏好的问题，而是直接转化为更小的面积、更高的频率和更少的 bug。

## 原理

### 命名规范与信号约定

统一的命名规范是可维护 RTL 代码的基石。信号名应清晰表达功能和方向：`_i`（input）、`_o`（output）、`_io`（bidirectional）后缀帮助审阅者快速判断信号方向；`_n` 后缀标识低电平有效信号（如 `rst_n`），避免在逻辑中混淆正反极性。时钟域前缀（如 `clk_sys_`、`clk_mem_`）对于多时钟设计至关重要——让 CDC 工具和人眼都能迅速识别跨域信号。参数（parameter/localparam）使用大写加下划线（`DATA_WIDTH`），区别于小写的信号变量。

模块命名采用小写加下划线（如 `axi_fifo`、`lsu_alu`），文件名与模块名保持一致，有利于 grep 搜索和自动脚本遍历。Interface 命名使用 `_if` 后缀，避免与同名 module 冲突。

### FSM 编码模板

状态机的 Verilog/SystemVerilog 实现应遵循三段式（Three-Process）风格：第一段用 `always_ff @(posedge clk or negedge rst_n)` 描述状态寄存器（当前状态 ← 次态），第二段用 `always_comb` 描述次态逻辑（纯组合逻辑，case over 当前状态和输入），第三段描述输出逻辑。三段式分离将状态跳转、次态计算和输出生成解耦，避免了组合环路和 inferred latch。

如果是 Moore 状态机（输出仅取决于当前状态），输出逻辑也可合并到第二段中用寄存器输出。对于 Mealy 状态机（输出取决于当前状态和输入），第三段 `always_comb` 是必须的。

关键编码细节：case 语句必须有 `default` 分支（通常赋值为当前状态以避免意外跳转，或跳转到安全恢复状态），使用 SystemVerilog `unique case` 提供综合时的互斥性断言，避免使用 `full_case`/`parallel_case` 综合指令（它们只影响综合，不影响仿真，容易导致仿真/综合不一致的隐藏 bug）。

### 可综合子集与陷阱

在数千条 SystemVerilog 语法规则中，只有约 30% 是可综合的。必须牢记仿真专属的构造在综合时会被忽略或报错：`initial` 块（仅在仿真零时刻执行）、`fork/join`（动态并发，无静态硬件对应）、`#delay`（综合忽略，导致 RTL 仿真与门级仿真在时序上可能不一致）、`$display/$monitor`（综合忽略）、class 类型声明在模块内部（综合不支持动态 OOP，但 UVM/验证代码中使用是正常的）。

四大致命 RTL 问题：(1) **inferred latch（推断锁存器）** — `always_comb` 中的不完整 if（缺少 else）或不完整 case（缺少 default）会推断出锁存器，锁存器在时序分析和 DFT 中是灾难；(2) **multiple drivers（多驱动）** — 同一信号在多个 `always` 块中被赋值，综合报错或产生竞争；(3) **combinational loop（组合环路）** — 组合逻辑输出反馈到自身输入，综合工具可以检测但不总能正确断开，导致仿真结果不确定；(4) **blocking assignment in sequential always（时序块中的阻塞赋值）** — `always_ff` 中使用 `=` 而非 `<=` 会导致仿真与硬件行为不一致（阻塞赋值立即更新后面的语句能读到新值，而非阻塞赋值并发更新）。

### CDC 编码最佳实践

跨时钟域设计不仅需要正确的同步器电路，还需要在 RTL 编码层面遵循严格的规则。时钟域命名前缀是最基本的实践：`clk_a_` 前缀 vs `clk_b_` 前缀使 CDC 路径一目了然。同步器单元应作为独立模块例化，并添加 `(* don_touch = "true" *)` 属性，防止综合工具"优化"掉看似冗余的同步器 FF（综合工具不知道这些 FF 在防止亚稳态）。

异步 FIFO 的读写指针编码、满空条件、Gray 码转换和同步逻辑应该封装在统一的 `async_fifo` wrapper 模块中，避免在各个子模块中重复手写 CDC 逻辑。CDC 信号的白名单（同步器输出标记为 safe）与黑名单（跨域信号未经过同步器）需要通过 SpyGlass CDC 或 Questa CDC 这类工具验证，而不是仅靠 code review。

## 关键要点

- 命名规范是 RTL 代码的第一道防线：一时钟域前缀、二方向后缀（_i/_o）、三极性（_n）、四包大写参数，信号名字本身就是文档
- 三段式 FSM 将状态跳转、次态计算和输出生成分离到三个 always 块中，是经过工业验证最不易出错的模板
- `unique case` 优于 `full_case` 注释：前者仿真和综合行为一致，后者仅影响综合导致仿真-综合不匹配
- 阻塞赋值（=）用于组合逻辑，非阻塞赋值（<=）用于时序逻辑——交叉使用是 bug 的首要来源
- 推断锁存器、多驱动、组合环路和时序块中的阻塞赋值，是 RTL 设计的"四大致命问题"
- 同步器模块化并加 `don_touch` 属性，是防止综合工具"好心办坏事"的保险
- 参数化（parameter）优于硬编码数字，generate 语句用于结构的规律性复制而非逻辑的复制
- lint 工具（SpyGlass Lint、Questa Lint、Verilator）应在每次提交前运行，其规则比人工 review 更全面一致

## 与其他概念的关系

- [[rtl-design/concepts/verilog-hdl|Verilog HDL]] — 编码风格的 Verilog 语法基础：阻塞/非阻塞赋值、always 块的正确使用
- [[rtl-design/concepts/fsm-design|有限状态机（FSM Design）]] — 三段式编码模板的详细展开
- [[rtl-design/concepts/cdc-cross-domain|RTL 跨时钟域（CDC）]] — CDC 编码规范：时钟域前缀、同步器模块化
- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — 编码风格直接决定综合 QoR，不可综合构造在此暴露
