---
type: concept
aliases:
  - SystemVerilog_系统Verilog
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
queries: 3
---
# SystemVerilog

SystemVerilog 是 Verilog HDL 的增强超集，由 Accellera 主导开发，2005 年被 IEEE 标准化为 IEEE 1800-2005（取代了 IEEE 1364 Verilog 标准），最新版为 IEEE 1800-2017。SystemVerilog 不仅统一了硬件描述（RTL）和硬件验证（Verification）两大领域，还引入了大量改善设计意图表达、降低编码错误和提高仿真效率的语言特性。对 RTL 设计而言，SV 将 Verilog 的 wire/reg 概念统一为 logic，引入了意图显式的 always_ff、always_comb 和 always_latch 块，补充了 interface、enum、struct、union、package 等高级抽象，使硬件设计代码的可读性、可维护性和 lint 检出率大幅提升。几乎所有现代 ASIC 和 FPGA 项目的 RTL 编码均已迁移到 SystemVerilog 可综合子集。

## 原理

### logic 类型与 wire/reg 的统一

Verilog 最令人困惑的设计缺陷之一是 wire 和 reg 的类型名称与实际硬件行为不一致——命名暗示 reg 是寄存器输出，但实际上组合逻辑的 always 块输出也必须声明为 reg。SystemVerilog 引入了 **logic** 类型（四值：0、1、X、Z），语义上表示"任意逻辑信号"，可以在 continuous assign、always 块和模块端口上统一使用，编译器根据上下文自动判断行为。logic 变量的关键语义是：**一个 logic 变量只能被一个源驱动**（即单驱动 Single-Driver 约束）。当信号需要多驱动场景时（如总线仲裁、三态门），必须使用 wire 或 tri 类型。这一设计从根本上消除了 wire/reg 的语义混乱，使初学者的学习曲线大幅平滑，也使 lint 工具（如 SpyGlass、Verilator）更容易检测多驱动冲突。logic 类型的另一个优势是默认值行为：logic 变量默认值为 X（未知），而非 Verilog reg 的 X 和 wire 的 Z，仿真时更容易暴露未初始化的设计错误。

### 意图显式的 always 块：`always_comb`、`always_ff`、`always_latch`

Verilog 中所有过程逻辑共用同一个 `always` 关键字——综合工具通过信号类型和代码模式**猜测**设计者的意图（究竟是组合逻辑？触发器？锁存器？）。猜错的代价是仿真与硅片行为不一致。SystemVerilog 的三个专用关键字从根本上解决了这个问题：**把意图（Intent）从隐式推断提升为显式声明**，让编译器和综合工具能够主动校验代码是否符合声明的意图。

#### `always_ff` — 触发器的显式宣言

**语义**：`always_ff` 声明"此过程块描述的电路必须被映射到边沿触发的时序元件（D 触发器/Flip-Flop）"。如果综合工具发现块内逻辑无法映射到触发器（如缺失时钟边沿、推断了组合回路），将产生**编译错误**而非静默警告。

**1. 灵敏度列表的强制约束**

```systemverilog
// ✅ 正确：always_ff 只接受边沿事件（posedge/negedge）
// 综合工具校验：输出信号必须映射到 Flip-Flop，不能是锁存器或组合逻辑
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)     q <= '0;          // 异步复位（低有效）
    else            q <= d;            // 正常采样
end

// ❌ 错误：边沿和非边沿信号不能同时出现在灵敏度列表中
// always_ff @(posedge clk or en)  → 编译错误：en 不是边沿事件

// ❌ 错误：组合逻辑放在 always_ff 中
// always_ff @(posedge clk) begin
//     y = a & b;    // 编译错误：y 是组合函数，不需要时钟边沿触发
// end
```

灵敏度列表规则：
- 只能包含 `posedge` 和 `negedge` 事件
- 不能混入电平敏感信号（如 `always_ff @(posedge clk or en)` 非法）
- 若设计需要异步复位，使用 `posedge clk or negedge rst_n`（两个边沿事件，合法）

**2. 必须使用非阻塞赋值（`<=`）**

```systemverilog
// ✅ 正确：always_ff 内部使用非阻塞赋值 <=
always_ff @(posedge clk) begin
    q <= d;                            // 非阻塞——所有 <= 在时间步末尾统一更新
end

// ❌ 错误：always_ff 内部使用阻塞赋值 =
always_ff @(posedge clk) begin
    q = d;                             // 阻塞——综合仍可能通过，但仿真语义错误
    // 问题：= 在当前时间步立即更新 q，破坏了触发器的边沿采样语义
    // 如果后续代码读取 q，读取的是"新"值而非"当前周期保持的旧值"
end
```

为什么 `always_ff` 必须 `<=`？触发器在物理上是时钟沿采样——在时钟沿到来时，所有触发器的输出同时由采样到的输入值决定。`<=` 的非阻塞语义精确建模了这一行为：所有 `<=` 右侧的表达式在时钟沿时刻（采样窗口）获取旧值，所有 `<=` 左侧的新值在 Re-NBA Region 统一更新。如果用 `=`，其后继语句读到的是"刚赋值的新值"而非"当前周期的旧值"——仿真波形与硬件行为脱节。

**3. 缺 else 不会推断锁存器——这是触发器，不是组合逻辑**

```systemverilog
// 新手常问：always_ff 中 if 没有 else，会推断出锁存器吗？
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)      q <= '0;          // 复位路径
    else if (en)     q <= d;           // 使能路径
    // 没有 else —— "en=0 时 q 不变" 是触发器的正常行为
    // 综合工具推断：q 的 CE（Clock Enable）引脚连接 en 信号
    // 不会推断锁存器！因为这是 always_ff —— "保持旧值" = Flip-Flop 自身行为
end

// 对比：always_comb 中缺 else → 锁存器（因为没有时钟边沿来采样保持）
```

这是 `always_ff` 与 `always_comb` 最本质的区别之一：在 `always_ff` 中，不完整的条件路径意味着"信号保持不变"——这正是触发器的硬件语义（时钟未使能时，FF 输出保持）。而在 `always_comb` 中，没有时钟来执行"保持"，只能推断锁存器。

**4. 复位策略：同步 vs 异步，及各自的综合行为**

```systemverilog
// ===== 同步复位（Synchronous Reset）=====
// 复位信号作为 D 输入端的 MUX 选择条件，不在灵敏度列表中
// 优点：STA 可精确约束复位释放路径，无 Recovery/Removal 时序问题
// 缺点：需要时钟在复位期间运行，额外消耗一个 MUX 的数据通路逻辑
always_ff @(posedge clk) begin
    if (rst)         q <= '0;          // 同步复位：rst 不在灵敏度列表中
    else             q <= d;
end
// 综合后的电路：D 输入端插入 2:1 MUX (rst ? 0 : d)

// ===== 异步复位（Asynchronous Reset）=====
// 复位信号在灵敏度列表中，使用 negedge 检测（低有效）
// 优点：复位不依赖时钟，可在无时钟时工作
// 缺点：复位释放需要满足 Recovery/Removal 时序约束
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)      q <= '0;          // 异步复位：rst_n 在灵敏度列表中
    else             q <= d;
end
// 综合后的电路：触发器的异步复位引脚直接连接 rst_n
// 注意：异步复位在 always_ff 中必须使用 negedge rst_n（列表中是边沿事件，合法）
```

**5. 时钟使能（Clock Enable）——综合到 D-FF 的 CE 引脚**

```systemverilog
// 时钟使能模式：综合工具将 MUX 反馈映射到工艺库 D-FF 的 CE 引脚
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)      q <= '0;
    else if (ce)     q <= d_in;        // CE=1 时采样新数据
    // ce=0 → q 保持旧值（触发器的内部反馈回路，不消耗数据通路时序）
end
```

综合工具识别 `if (ce) ... else (implicit keep)` 模式后，将 CE 信号连接到触发器库单元的 CE 引脚——此引脚位于触发器的**内部时钟路径**而非数据路径，因此 CE 信号不增加数据通路的建立时间。这是优于在数据输入端手动插入 MUX 的关键优势。

#### `always_comb` — 组合逻辑的安全网

**语义**：`always_comb` 声明"此过程块描述的电路必须被映射为纯组合逻辑（无状态、无时钟、无反馈），所有输出仅由其输入的当前值决定"。综合工具会主动检查并报告任何意外锁存器推断。

**1. 自动灵敏度列表（真正的"全自动"）**

```systemverilog
// always_comb 自动推导灵敏度列表——设计者不需要也不应该写 @(信号列表)
// 它追踪块内读取的所有信号（包括函数调用内部的信号，always @(*) 做不到这一点）

always_comb begin
    // 读取了 a, b, sel, op[0], op[1]，全部自动加入灵敏度列表
    // 即使通过函数调用 read_status() 间接读取的信号，也会被追踪
    if (sel)       y = a + b;          // 阻塞赋值 = （组合逻辑的正确赋值方式）
    else           y = read_status(op); // 函数 read_status 内部使用 op[0], op[1]
end
```

对比 `always @(*)` 的盲区：如果函数 `read_status` 内部读取了信号 `op[0]`，`always @(*)` 不会把 `op` 加入灵敏度列表——因为 `@(*)` 只看 always 块本身的直接信号引用，不会递归追踪函数内部。这意味着 `op` 变化时 `y` 不更新，造成仿真与实际的偏差。`always_comb` 自动填补了这个漏洞。

**2. 零时刻自动执行（时间 0 初始化）**

```
仿真行为差异：
  always @(*)：    时间 0 时不执行——需要等待至少一个信号变化事件才触发
  always_comb：    时间 0 自动执行一次——保证输出从 t=0 起即与输入一致

为什么重要：
  时间 0 的激励往往在 initial 块中设置（t=0 写入），如果 always @(*) 不触发，
  组合逻辑的输出在 t=0 是 X（未初始化），可能导致 initial 块之后的第一个读操作读到 X，
  引发下游的 $error 或 uvm_error（而实际硬件没有"t=0 的 X"这种状态）。
```

**3. 锁存器推断防护——编译时告警而非仿真时发现**

```systemverilog
// ❌ always_comb 中缺 else → 锁存器推断警告
always_comb begin
    if (en)          y = d;            // en=0 时 y 没有被赋值——y 必须"记住"旧值
    // 综合工具警告：[SYNTH-123] Latch inferred for signal y
    // 仿真时模拟：锁存器行为（en=0 时 y 保持，en=1 时 y 跟随 d）
end

// ✅✅ 最佳实践：默认值 + 条件覆盖（根本避免锁存器推断）
always_comb begin
    y = '0;                            // 默认值——所有输出变量在块开头赋值
    if (en)          y = d;            // 条件覆盖——en=1 时覆盖默认值
    // 无需 else——默认值已保证 en=0 时 y 有确定值
    // 综合结果：MUX (en ? d : '0)，无锁存器
end
```

**4. 自身赋值检测——提前捕获组合环路**

```systemverilog
// ❌ always_comb 中的组合环路（a = a + 1）
always_comb begin
    a = a + 1;                         // 编译错误：a 被自身赋值
end
// always @(*) 允许这种写法——仿真时 a 每一帧都变化，导致无限触发循环
// 综合工具推断组合环路——实际硬件振荡或不确定，形式验证无法分析
// always_comb 在编译阶段就直接报错，避免了一整条错误的发现链路
```

**5. 必须使用阻塞赋值（`=`）**

`always_comb` 中的赋值必须使用 `=`（阻塞）而非 `<=`（非阻塞）。原因：组合逻辑是即时响应的——输入变化后，经过门延迟，输出在同一仿真周期内确定新值。`=` 的即时更新语义精确匹配这一物理行为。如果用 `<=`，输出在当前仿真周期的剩余时间内保持旧值，下游组合逻辑读到的是"过时"的信号——典型的仿真与综合不匹配（Simulation-Synthesis Mismatch）。

#### `always_latch` — 锁存器的显式声明

```systemverilog
// always_latch：明确声明"这个锁存器是有意设计的，不是编码错误"
// 典型场景：门控时钟产生电路、特定低功耗保持单元
always_latch begin
    if (clk_gated)   q_latch <= d;     // clk_gated=1：透明模式（锁存器打开）
    // clk_gated=0：保持模式（锁存器关闭，保持 q_latch 的旧值）
    // 这里 if 无 else 是正常锁存器行为——always_latch 明确了这个意图
    // 综合工具不会产生 lint 警告（因为 always_latch 标签声明了意图）
end
```

`always_latch` 的存在价值在于**意图声明**：当 lint 工具检测到不完整 if 时，如果它在 `always_latch` 块内，lint 会沉默（因为设计者明确说"我要锁存器"）；如果在 `always_comb` 块内，lint 会报警（因为`always_comb` 承诺了纯组合逻辑，锁存器违背了此承诺）。

#### 三者的本质差异对照表

| 维度 | `always_ff` | `always_comb` | `always_latch` |
|:---|:---|:---|:---|
| **硬件目标** | 边沿触发的 Flip-Flop | 纯组合逻辑（无状态） | 电平敏感的锁存器 |
| **灵敏度列表** | 仅 `posedge`/`negedge` | 自动推导（不可手动指定） | 电平敏感信号（通常 `*` 或 `@(gate, data)`） |
| **赋值类型** | 非阻塞 `<=` | 阻塞 `=` | 通常 `=`（锁存器透明路径是组合逻辑） |
| **缺 else 的行为** | 保持旧值（FF 自身行为，**不推断锁存器**） | **推断锁存器 + 编译告警** | 保持旧值（锁存器行为，**无 lint 告警**） |
| **自身赋值检测** | 允许（`q <= q + 1` 是计数器） | **编译报错**（`a = a + 1` 是组合环路） | 取决于上下文 |
| **时间 0 执行** | 否（等待第一个时钟沿） | **是**（自动执行一次初始值计算） | 否 |
| **函数内灵敏度追踪** | 不适用（边沿触发） | **自动追踪**（函数内信号也在灵敏度列表中） | 不适用 |
| **综合校验** | 断言输出映射到 FF，否则编译错误 | 断言无锁存器，否则 lint 告警 | 断言灵敏度列表为电平敏感 |

#### 从 Verilog `always` 迁移的速查表

| Verilog 模式 | SystemVerilog 等价 | 关键变化 |
|:---|:---|:---|
| `always @(posedge clk)` | `always_ff @(posedge clk)` | 语义校验 + 灵敏度列表约束 |
| `always @(posedge clk or negedge rst_n)` | `always_ff @(posedge clk or negedge rst_n)` | 同上 |
| `always @(*)` 组合逻辑 | `always_comb` | 零时刻执行 + 自身赋值检测 + 函数内灵敏度 |
| `always @(a or b or c)` | `always_comb` | 不需要手动维护灵敏度列表 |
| `always @(gate or data)` 有意锁存器 | `always_latch` | 明确意图声明 |
| `always @(posedge clk) ... a = a + 1;` | **改为** `always_ff @(posedge clk) ... a <= a + 1;` | 阻塞→非阻塞 |

### interface 与 modport

传统 Verilog 中，模块互联需要逐个声明端口连接线，当总线位宽大、信号数量多时（如 AHB、AXI 总线可能包含数百个信号），端口列表声明冗长且极易出错——增加一个信号需要修改所有经过该总线的模块端口列表。SystemVerilog 的 **interface** 将相关信号打包为一个可复用的逻辑组，模块只需在端口列表中声明一个 interface 实例即可接入整个总线。**modport** 是 interface 的方向限定（Direction Qualifier），为同一个 interface 中的信号定义不同模块视角的方向（master/slave/monitor），编译时即可检查方向错误。interface 还支持参数化（parameterized interface）和嵌套（nested interface），配合 clocking block 可以精确控制时钟域边界的时序采样。

### enum、struct、union 与 package

**enum**（枚举类型）将状态机的状态编码从裸整数提升为命名常量，提高可读性并允许综合工具进行最优编码选择。**struct**（结构体）将相关信号打包为单一类型，便于总线数据的总线级操作，如 `struct packed { logic [7:0] addr; logic [31:0] data; } mem_cmd_t` 可在单周期内作为 40 位向量整体赋值和比较。**union**（联合体）允许同一存储空间以不同方式解释位模式，常用于寄存器位域重映射。**package** 将公用的类型定义、parameter、function 和 task 封装为命名空间，通过 `import my_pkg::*` 导入，替代了 Verilog 中 `include 头文件的全局污染问题。package 支持选择性导入（如 `import my_pkg::my_type`）和通配符导入，并提供了编译单元级别的封装隔离。

### DPI（Direct Programming Interface）

DPI 是 SystemVerilog 与 C/C++ 函数双向调用的标准接口。通过 `import "DPI-C" function int my_func(input int a);` 声明，SystemVerilog 代码可以直接调用 C 函数；通过 `export "DPI-C" function my_sv_func;` 声明，C 代码可以回调 SystemVerilog 函数。DPI 是构建仿真模型（如 ISS、Bus Functional Model）、参考模型（Reference Model）和 co-simulation 环境的核心桥梁，使 UVM 验证环境可以复用 C/C++ 黄金模型。


### 类型转换与位宽控制

SystemVerilog 提供了远强于 Verilog 的类型转换机制。**静态转换（Static Cast）** 使用 `type'(expr)` 语法——如 `int'(a + b)` 将运算结果强制转换为 int 类型，转换在编译时进行、不检查溢出。**动态转换（Dynamic Cast）** 使用 `$cast(dest, src)`，在仿真时检查转换的合法性并返回成功/失败标志。对于位宽不匹配的赋值，SV 的位宽截断和扩展规则与 Verilog 兼容——宽向窄赋值高位截断，窄向宽赋值时无符号数零扩展、有符号数符号扩展——但 SV 提供了 `$bits()`、`$left()`、`$right()` 等尺寸内省函数使位宽操作更安全。`$clog2()`（Ceiling Log Base 2）是参数化设计中计算地址位宽、FIFO 深度所需比特数的必备函数。SV 还引入了 `let` 声明（编译时宏函数）作为 `define 宏的类型安全替代。

### SVA 断言在 RTL 中的应用

虽然 SVA（SystemVerilog Assertions）主要用于验证，但即时断言（Immediate Assertions）是可综合的——综合工具将它们映射到硬件检查器电路。即时断言 `assert (condition) else $error("msg");` 被综合为组合逻辑，当条件为假时拉高错误输出信号，类似于硬件的在线自检（Built-In Self-Check）。`assume` 断言向综合工具传达环境假设——例如告知综合工具某些时序关系在环境中总是成立，综合工具可利用这些约束进行逻辑优化（去除"不可能发生"的条件逻辑）。集成 SVA 的 RTL 综合产生的 checker 逻辑通常应使用 `ifdef ASSERT_ON` 宏围绕，以便在后端物理设计中剥离断言逻辑。


SystemVerilog 通过属性（Attributes）传递综合和仿真的元信息。关键属性包括：`(* ram_style = "block" *)` 指示综合工具使用 Block RAM 而非分布式 RAM；`(* keep = "true" *)` 防止综合工具优化掉特定线网（如调试信号）；`(* dont_touch = "true" *)` 确保关键结构（如 CDC 同步器）不被综合优化或克隆破坏；`(* async_reg = "true" *)` 标记 CDC 同步器第一级触发器，使布局布线工具将其靠近放置以最小化亚稳态窗口。时钟门控指令 `(* clock_gating = "true" *)` 通知综合工具在寄存器组上插入 ICG 单元。综合属性直接影时钟门控插入率，正确的属性标注可降低 20-40% 的时钟树动态功耗。

### 综合属性与指令

SystemVerilog 通过属性（Attributes）传递综合和仿真的元信息。关键属性包括：`(* ram_style = "block" *)` 指示综合工具使用 Block RAM 而非分布式 RAM；`(* keep = "true" *)` 防止综合工具优化掉特定线网（如调试信号）；`(* dont_touch = "true" *)` 确保关键结构（如 CDC 同步器）不被综合优化或克隆破坏；`(* async_reg = "true" *)` 标记 CDC 同步器第一级触发器，使布局布线工具将其靠近放置以最小化亚稳态窗口。时钟门控指令 `(* clock_gating = "true" *)` 通知综合工具在寄存器组上插入 ICG 时钟门控单元。



### 生成块的高级用法

SystemVerilog 的 **generate** 结构（generate-for、generate-if、generate-case）是可综合的硬件生成语法，用于参数化创建重复电路。`generate-for` 使用 `genvar` 循环变量，在编译时展开为多个并行硬件实例——典型用例包括：N 位总线信号的逐比特 2-FF 同步器组、多通道 FIFO 的并行实例数组、多级流水线寄存器的逐级例化。`generate-if` 根据参数条件选择互斥的硬件结构体——如 `if (DATA_WIDTH < 16) rca_adder #(.W(DATA_WIDTH)) u_adder (...) else cla_adder #(.W(DATA_WIDTH)) u_adder (...)`。generate 块内的信号声明必须是局部作用域（每个 generate 迭代创建独立的信号副本），避免在 generate 块内声明共享信号导致的命名冲突。

### always_comb 与 always @(*) 的关键语义差异

虽然 `always_comb` 和 `always @(*)` 在功能上看似等效（都描述组合逻辑），但 `always_comb` 有三个关键增强：1) **零时刻执行**——`always_comb` 在仿真的时间零自动执行一次以计算初始值，而 `always @(*)` 必须在所有输入经历事件后才首次触发，这意味着 `always_comb` 保证了仿真开始时的输出与输入一致；2) **禁止自身赋值**——`always_comb` 自动禁止块内的信号被同一信号赋值（如 `a = a + 1` 是组合环路错误），而 `always @(*)` 允许这种写法（导致仿真无限循环或综合错误）；3) **函数调用内的灵敏度**——`always_comb` 自动追踪 always 块内调用的函数中使用到的信号（函数内读取的信号也会加入灵敏度列表），而 `always @(*)` 仅追踪 always 块本身直接读取的信号（函数内的信号引用被漏掉）。这些差异使得 `always_comb` 是比 `always @(*)` 更安全、更完整的组合逻辑建模方式。

### 可综合子集边界：什么能写，什么绝对不能写

综合工具是一台"硬件编译器"——它读取 RTL 源码，输出逻辑门和触发器的网表。但它只理解 SystemVerilog 的一个严格子集：**可综合子集（Synthesizable Subset）**。超出子集的代码在仿真中可以完美运行（仿真器实现了整个 LRM），但综合工具要么忽略（静默丢失逻辑），要么报错并终止。**写不能被综合的代码在 RTL 设计中是禁止的——这会直接导致仿真通过但硅片失败的灾难性后果。**

以下按类别列出所有不可综合的结构及其原因，每一类都必须牢记。

#### 第一类：时序控制 —— 硬件无法定义"绝对时间"

| 结构 | 为何不可综合 | 后果 |
|:---|:---|:---|
| `#N` 延迟（如 `#5 a = b;`） | 硅片没有"等 5 个时间单位"的概念——门延迟由物理特性和 PVT 条件决定，不由 RTL 控制 | 综合时被忽略——仿真中看到的延迟在硅片上不存在 |
| `#0` 零延迟 | 用于仿真中强制事件重新调度，无硬件等价物 | 同被忽略 |
| `wait (expr)` 电平等待 | 硬件无法"暂停并等待条件满足"——所有逻辑由时钟同步驱动 | 综合报错 |
| `@(posedge a)` 在非 always_ff 上下文中 | 边沿检测只能在 always_ff 的灵敏度列表中 | 综合不理解意图 |
| `forever` 循环 | 无终止条件 → 展开次数无限 → 硬件无法实现无限长的组合逻辑链 | 综合报错 |

```systemverilog
// ❌ 不可综合示例
always @(posedge clk) begin
    #5 data <= input_data;     // #5：硅片上没有"5个时间单位"
end

initial begin                    // initial：只在仿真时间0执行一次，无硬件等价
    wait (reset_n == 1);        // wait：硬件无法"暂停等待"
    forever #10 clk = ~clk;     // forever + #delay：纯仿真构造
end
```

#### 第二类：仿真专用过程块 —— 不存在于硬件时间轴中

| 结构 | 为何不可综合 | 替代方案 |
|:---|:---|:---|
| `initial` 块 | 仅在仿真时间 0 执行一次——硬件上电后没有"执行一次然后消失"的概念。复位逻辑用 always_ff + rst_n 实现，不是 initial | `always_ff @(posedge clk or negedge rst_n)` |
| `final` 块 | 仅在仿真结束时执行——硬件没有"仿真结束"事件 | 不可替代（仅仿真辅助检查用） |
| `fork/join` / `fork/join_any` / `fork/join_none` | 动态并行执行——硬件的并行性由物理结构决定（多个模块、多个 always 块同时存在），不是"fork 临时创建线程" | 多个独立的 `always_ff` 块 |
| `disable` 语句 | 终止命名块——硬件无法"杀死"一个已经存在的逻辑电路 | 无等价物 |
| `event` 类型 + `->` / `@` 触发器 | 仿真事件的同步机制——硬件信号通过连线传播，不需要抽象事件 | wire + always_ff 同步 |

#### 第三类：系统任务 —— 没有对应的硬件资源

**全部系统任务 (`$xxx`) 均不可综合**。综合工具遇到 `$display`、`$monitor` 等会将其忽略（不产生硬件），但如果在 `$display` 的参数中引用了寄存器——该寄存器仍会被综合（因为其他可综合代码使用了它），只是打印行为在硅片上消失了。

| 常用系统任务 | 用途 | 综合行为 |
|:---|:---|:---|
| `$display`, `$write`, `$strobe`, `$monitor` | 打印/监控 | 被忽略（无硬件） |
| `$time`, `$realtime`, `$stime` | 获取仿真时间 | 被忽略 |
| `$random`, `$urandom`, `$dist_xxx` | 随机数生成 | 被忽略——硅片不会生成随机数 |
| `$stop`, `$finish`, `$fatal` | 停止/终止仿真 | 被忽略 |
| `$fopen`, `$fwrite`, `$fclose` | 文件操作 | 被忽略 |
| `$readmemh`, `$readmemb` | 从文件加载存储器初始化 | **特殊例外**：部分综合工具支持（用于 ROM/RAM 初始化），但不保证跨工具一致 |
| `$asserton`, `$assertoff`, `$assertkill` | 断言控制 | 被忽略 |
| `$clog2` | 数学函数（天花板 log2） | **可综合**——这是少数可综合的系统函数 |

**注意**：`$readmemh`/`$readmemb` 是特殊例外——多数 FPGA 综合工具（Vivado、Quartus）支持它们用于 BRAM 初始化，但 ASIC 流程中不保证一致性，应使用 `initial` + `force` 或工具特定的存储器初始化命令。

#### 第四类：层次引用与强制赋值 —— 破坏模块边界

| 结构 | 为何不可综合 | 替代方案 |
|:---|:---|:---|
| 层次引用 XMR（Cross-Module Reference）: `top.u_core.sig` | 破坏了模块的端口封装——一个模块的内部信号名字变化会导致另一个模块的综合失败 | 通过端口连接传递信号 |
| `force` / `release` | 在仿真中强行改变信号值——硬件中不存在"在一个模块中强行改写另一个模块内部连线"的机制 | 测试平台专用，RTL 中禁止 |
| `assign ... deassign` | 过程化连续赋值——同样破坏硬件信号单向驱动 | 已从 IEEE 1800 中弃用 |

#### 第五类：动态与验证专用数据类型 —— 硬件资源必须在编译时确定

| 结构 | 为何不可综合 | 替代方案 |
|:---|:---|:---|
| `class` (类) | 面向对象的动态特性——硬件没有运行时动态分配的对象 | `struct` + `module` |
| `virtual interface` | 仿真器中的一个"接口指针"——硬件没有指针 | 物理 `interface` 实例 |
| `mailbox`, `semaphore` | 进程间通信/同步——仿真的动态并发模型 | 无硬件等价物（FIFO + 状态机） |
| `dynamic array` (`[]`) | 大小在运行时变化——硬件不能"增长"或"收缩"一组寄存器 | `unpacked array [0:N-1]`（固定大小） |
| `queue` (`[$]`) | 运行时 push/pop——硬件没有链表 | shift register / FIFO |
| `associative array` (`[*]`) | 哈希表——硬件没有哈希函数和动态内存分配 | 固定大小的 RAM + 地址映射 |
| `string` | 可变长度字符串——硬件没有 ASCII 字符串处理器 | `logic [7:0]` 固定位宽字符 |
| `real` / `shortreal` (浮点) | 浮点运算需要专门的浮点单元（FPU）——不能直接综合为随机逻辑门 | 定点运算 `logic signed`，或实例化 FPU IP |
| `time` 类型 | 仿真时间变量——硬件没有"仿真时间"概念 | `logic [63:0]` 计数器 |
| `chandle` | C 指针——硬件没有 C 运行时 | 不可替代 |

#### 第六类：循环与分支的静态约束

**循环可综合的必要条件：循环次数必须在编译时已知（静态展开上限）。**

```systemverilog
// ✅ 可综合：always @(*) + 固定循环 + 先初始化再累加 = 加法器链
// 关键：sum='0 初始化后，for 循环内的 sum=sum+data[i] 在单次执行中是顺序阻塞赋值
// 展开后等价于：sum = data[0] + data[1] + data[2]
// 综合结果：三层加法器，每层输出连到下层输入——加法器链，不是组合环路
always @(*) begin
    sum = '0;
    for (int i = 0; i < 3; i++) begin
        sum = sum + data[i];
    end
end

// ⚠️ 但 always_comb 会拒绝上面的写法——为什么？
// always_comb 的自身赋值检测在**语法层面**看到 sum 同时出现在等号左右
// 就直接报编译错误。它不去分析"有没有初始化"、"是不是在循环内"——
// LRM 选择了保守策略：宁可误杀加法器链，也不漏过一个真正的组合环路。
// 因此 always_comb 中必须改用 generate-for（见下方正确做法）。

// ❌ 真的组合环路：缺少初始化
// sum 在第一次执行时是 X，X + data[0] = X，输出永远 X
// 综合工具推断振荡/不确定电路
always @(*) begin
    for (int i = 0; i < 3; i++) begin
        sum = sum + data[i];       // 没有 sum='0 初始化 → sum 读取的是旧值 → 组合环路
    end
end

// ❌ 不可综合：循环次数在运行时变化（N 是运行时信号，非编译时常量）
int N = config_reg;              // config_reg 是硬件信号，不是 parameter
for (int i = 0; i < N; i++) begin
    // 编译时不知道要展开多少次——综合工具无法处理
end

// ❌ 不可综合：while 无静态展开上限
while (data != 0) begin          // 循环次数未知——综合工具无法展开
    data = data >> 1;
end

// ❌ 不可综合：do...while 同样没有静态展开上限
do begin
    cnt = cnt + 1;
end while (cnt < threshold);
```

**正确做法**：`always_comb` 场景用 `generate-for` + `assign`（每个迭代是独立语句），普通 `always @(*)` 可以直接用 `for` + 先初始化。

```systemverilog
// ✅ 方式一：always_comb 中用 generate-for（回避自身赋值检测）
logic [31:0] partial [0:8];        // 部分和数组
assign partial[0] = '0;
genvar i;
generate
    for (i = 0; i < 8; i++) begin : gen_adder_chain
        assign partial[i+1] = partial[i] + data[i];
        // 每次 assign 是独立语句——partial[i+1] 和 partial[i] 是不同的变量
        // 不存在"同一个变量出现在等号左右"的问题
    end
endgenerate
assign sum = partial[8];

// ✅ 方式二：always @(*) 直接用 for + 初始化（比 generate-for 简洁）
always @(*) begin
    sum = '0;
    for (int i = 0; i < 8; i++) begin
        sum = sum + data[i];       // 先初始化了 sum，每次循环的 sum 都已在上一次循环中确定
    end
end
// 综合结果：八层加法器链，无组合环路
// 缺点：不是 always_comb——丢失了零时刻执行和自身赋值检测的保护

// ✅ 方式三：元素少时直接写出（最清晰）
assign sum = data[0] + data[1] + data[2] + data[3]
           + data[4] + data[5] + data[6] + data[7];

// ✅ 方式三：always_ff 中的累加器（时序逻辑——sum <= sum + data[i]，允许自身赋值）
always_ff @(posedge clk) begin
    if (en) sum <= sum + data[idx];  // 非阻塞赋值 <=：右侧是旧值，不冲突
end
```

**关键区分**：

| 写法 | `always_comb` | `always_ff` | `assign` |
|:---|:---|:---|:---|
| `x = x + y` 在 `always_comb` 中 | ❌ 编译报错（自身赋值检测——LRM 语法层面拒绝，不管是否初始化） | — | — |
| `x = x + y` 在 `always @(*)` 中（先初始化 x） | — | — | ✅ 加法器链（阻塞赋值顺序执行，非组合环路） |
| `x = x + y` 在 `always @(*)` 中（未初始化 x） | — | — | ❌ 组合环路（读取旧值 X） |
| `x <= x + y` 在 `always_ff` 中 | — | ✅ 计数器（非阻塞 `<=` 读旧值） | — |
| `x = a + b` | ✅ 组合逻辑 | ❌（应该用 always_comb） | ✅ 连续赋值 |

#### 第七类：组合逻辑陷阱 —— 可综合但行为错误

以下结构综合工具不会报错（会生成硬件），但生成的硬件行为与设计者预期几乎必然不一致：

| 陷阱 | 综合行为 | 正确做法 |
|:---|:---|:---|
| **不完整 if/case → 锁存器** | 推断电平敏感锁存器（Latch），而非纯组合逻辑 | always_comb 中所有输出变量在块头赋值默认值 |
| **组合环路（A=B; B=A;）** | 推断振荡器/不确定电路——STA 无法分析，DFT 无法测试 | 断开环路——在其中一条路径上插入寄存器 |
| **多驱动（两个 always 块驱动同一信号）** | 综合为短路/冲突——多个门输出短接，实际为 X 态或烧毁 | 一个信号只有一个 always 块（或一个 assign）驱动 |
| **混合阻塞/非阻塞赋值同一信号** | 仿真顺序依赖 → 仿真与综合行为差异（Sim-Synth Mismatch） | always_comb 用 `=`，always_ff 用 `<=` |
| **异步复位 + 同步释放混用** | 不同触发器的复位释放时序不同 → 芯片级混乱 | 统一复位策略，异步复位同步释放模块放入专门的 reset_sync 模块 |

#### 分类速记表

一张表记住所有不可综合结构——贴在显示器旁边：

```
═══════════════════════════════════════════════════════════════
  绝对禁止（RTL 中写了就是错误）
═══════════════════════════════════════════════════════════════
  #N 延迟    initial    forever    fork/join    wait
  force      release    disable    event ->@    $display/$monitor/...
  class      mailbox    semaphore  queue [$]    dynamic array []
  string     real       time       chandle      虚接口
  while      do...while (在 RTL 中)   层次引用 XMR
═══════════════════════════════════════════════════════════════
  允许但危险（综合通过 ≠ 硬件正确）
═══════════════════════════════════════════════════════════════
  不完整 if → 锁存器    组合环路    多驱动    混用 <=/=
═══════════════════════════════════════════════════════════════
```

**核心原则**：如果你不确定一个写法能不能综合，查 LRM 可综合子集文档，或者问自己"这个写法对应什么硬件？"——如果答不上来，它就是不可综合的。RTL 的每一行代码都必须有清晰的硬件映射意图。

### 不可综合语句速查

| 语句/结构 | 类别 | 为何不可综合 |
|:---|:---|:---|
| `#10 a = b;` | 时序控制 | 硅片无绝对时间概念——门延迟由 PVT 决定 |
| `initial ...` | 仿真专用 | 仅执行一次，无硬件等价物 |
| `forever #5 clk = ~clk;` | 无限循环+延迟 | 纯仿真时钟生成 |
| `fork/join` | 动态并发 | 硬件并行是结构性的，非动态创建线程 |
| `wait (sig == 1)` | 电平等待 | 硬件无法"暂停等待条件" |
| `force a = 1; release a;` | 强制赋值 | 破坏模块封装和信号驱动 |
| `class MyClass; ... endclass` | OOP | 动态对象分配无硬件对应 |
| `mailbox m = new();` | IPC | 进程间通信，非硬件资源 |
| `int arr[]; arr = new[10];` | 动态数组 | 运行时大小变化——硬件无动态分配 |
| `while (data != 0) data >>= 1;` | 无界循环 | 循环次数编译时不可知 |

**记忆口诀**：无 delay、无 initial、无 fork、无 wait/force、无 class/mailbox/dynamic、无 while——这些都是仿真专属语法。

## wire 与 reg 的深层辨析及 logic 的统一

### tri 类型与多驱动场景

`tri` 类型在 Verilog 中与 `wire` **完全等价**（`tri` 即 `wire tri;` 的简写），仅作为**语义标记**使用——`tri` 表示该线网预期由多个源驱动（如三态总线）。在 SystemVerilog 中，`logic` 严格执行**单驱动约束**（Single-Driver Rule）：一个 `logic` 变量只能在一个 always 块、一个 assign 语句或一个模块实例输出中被驱动。当需要多驱动时（如三态门总线的线与/线或），必须使用 `wire` 或 `tri`：

```systemverilog
// logic 单驱动——编译时多驱动报错
logic [7:0] bus_data;
assign bus_data = tx_active ? tx_data : 8'bz;    // 驱动源1
// assign bus_data = rx_data;                     // ❌ 编译错误：logic 只能有一个驱动源

// wire/tri 多驱动——三态总线场景
wire [7:0] tri_bus;
assign tri_bus = driver_a_en ? data_a : 8'bz;     // 驱动源1（高阻时为 z）
assign tri_bus = driver_b_en ? data_b : 8'bz;     // 驱动源2（线与——多个 z 可共存）
```

### var 关键字：显式声明变量类型

SystemVerilog 引入了 `var` 关键字显式声明变量（Variable）——与 `wire` 线网相对。`logic` 实际上是 `var logic` 的默认行为（当声明在过程块内时）：

```systemverilog
var logic [7:0] cnt;      // 显式声明 cnt 为变量（过程赋值用，如 always_ff 中）
wire logic [7:0] sig;     // 显式声明 sig 为线网（连续赋值用，如 assign 中）
// logic [7:0] x;         // 默认推断——根据上下文自动判断 var 或 wire
```

### 双向端口为什么用 wire

双向端口（inout）必须声明为 `wire`（或 `tri`），**不能用 logic**。原因：双向端口本质上是多个驱动源共享同一物理连线——外部芯片输出的数据驱动该端口，内部模块也驱动该端口——这是"多驱动"场景，违背了 logic 的单驱动约束：

```systemverilog
module bidir_if (
    inout wire [7:0] data_bus,        // ✅ 双向端口必须用 wire（多驱动）
    input logic      dir,             // 方向控制：1=输出，0=输入
    input logic [7:0] tx_data,        // 待发送数据
    output logic [7:0] rx_data        // 接收到的数据
);
    assign data_bus = dir ? tx_data : 8'bz;   // 输出路径：dir=1 时驱动总线
    assign rx_data = data_bus;                 // 输入路径：始终读取总线状态
endmodule
```

### reg 什么时候综合成组合逻辑 / 寄存器

**reg 类型名称不决定综合结果**——这是 Verilog 最经典的认知陷阱。reg 综合为何种硬件完全由 always 块的敏感列表和内部逻辑决定：

| always 块写法 | sensitive list | 综合结果 |
|:---|:---|:---|
| `always @(*)` + 完整条件 | 电平敏感 | 组合逻辑门（尽管输出声明为 reg）|
| `always @(posedge clk)` | 边沿敏感 | D 触发器 / 寄存器 |
| `always @(*)` + 不完整 if/case | 电平敏感 | 锁存器（Latch） |

**判断规则**：reg 在边沿敏感的 always 块（`posedge clk`）中被赋值 → 寄存器；reg 在电平敏感的 always 块（`@(*)`）中被赋值且所有输入组合都有确定的输出 → 组合逻辑；reg 在电平敏感的 always 块中被赋值但存在未覆盖的输入组合 → 锁存器。SystemVerilog 的 `logic` 类型遵循相同的推断规则——logic 本身也不决定硬件实现。

## task 与 function 的区别及使用场景

task（任务）和 function（函数）是 Verilog/SystemVerilog 中过程代码复用的两种机制，核心区别在于**时序控制能力**和**返回方式**：

| 维度 | function | task |
|:---|:---|:---|
| 时序控制（`#`/`@`/`wait`） | **禁止** | **允许** |
| 返回值 | 至少一个（通过函数名或 return），可多输出端口 | 通过 output/inout 参数返回多个值 |
| 调用方式 | 表达式内：`y = func(a, b);` | 过程语句：`my_task(a, result);` |
| 仿真时间消耗 | 0 时间（单时间步内完成） | 可跨多个时间步（有时序控制时） |
| 可综合条件 | 无时序控制 + 组合逻辑描述 | 无时序控制 + 组合/时序逻辑描述 |
| 内部 always/initial | 禁止 | SystemVerilog 允许 |

```systemverilog
// ===== function：纯组合逻辑（可综合） =====
// 计算两个向量的按位与并返回结果
function automatic logic [7:0] bitwise_and (
    input logic [7:0] a,        // 输入参数 a（8 位）
    input logic [7:0] b         // 输入参数 b（8 位）
);
    bitwise_and = a & b;        // 通过函数名返回（传统 Verilog 风格）
    // 或使用：return a & b;    // SystemVerilog 风格（更推荐）
endfunction

// ===== task：支持多输出参数（可综合，无时序控制） =====
// 同时计算和与进位——返回两个结果
task automatic adder_with_carry (
    input  logic [7:0] a,       // 加数 a
    input  logic [7:0] b,       // 加数 b
    output logic [7:0] sum,     // 和（输出参数）
    output logic       carry    // 进位（输出参数）
);
    {carry, sum} = a + b;       // 拼接进位与和，赋值给输出参数
endtask
```

### automatic task/function 与静态默认

Verilog-1995 中 task/function 默认是 **static**（静态）——内部变量在多次调用间共享存储空间，这是硬件思维的延续（硬件寄存器的值是持久的）。但对于**递归调用**或需要在仿真中多次独立调用的场景，静态存储会引发调用间的值覆盖问题。**Automatic task/function** 在每次调用时分配独立的存储空间（类似 C 语言的栈帧），支持递归和可重入调用：

```systemverilog
// automatic function：递归计算阶乘（仿真用，不可综合）
function automatic int factorial(input int n);
    if (n <= 1)
        return 1;                              // 递归终止条件
    else
        return n * factorial(n - 1);           // 递归调用自身（需要 automatic）
endfunction
```

### 为什么 function 不能调用 task

Verilog 强制 function 必须在**零仿真时间**内完成——function 不能包含 `#delay`、`@(event)`、`wait(expr)` 等时序控制语句。而 task 允许包含这些时序控制。如果 function 可以调用 task，那么 task 中的 `#10` 等待会迫使父 function"暂停"——违反 function 零时间的语义约束。SystemVerilog 部分放宽了此限制：**允许 function 调用 task，但前提是该 task 不包含任何时序控制**。

### void function：无返回值的函数式调用

`void function` 是 SystemVerilog 的特殊用法——函数不返回值（或返回值被丢弃），以函数语法调用但用于副作用（如修改输出参数）：

```systemverilog
function automatic void increment_counter(
    input  logic [7:0] in,
    output logic [7:0] out
);
    out = in + 1'b1;                           // 通过输出参数返回结果
endfunction

// 调用方式与 task 类似——不需要接收返回值
increment_counter(data, result);
```

### 可综合 task 的条件

task 可综合的**充分必要条件**：1) 无时序控制（无 `#`/`@`/`wait`/`fork`）；2) 所有路径在有限时间内完成（无无限循环）；3) 输入输出信号映射到可综合硬件（无动态对象）。满足这些条件的 task 本质上是"能同时返回多个输出的 function"——综合工具将其展开为独立的硬件逻辑块。

## interface 与 module 的区别

| 维度 | module | interface |
|:---|:---|:---|
| 本质 | 层次化设计的基本单元——封装功能逻辑 | 信号组的封装容器——将相关信号打包为可复用总线 |
| 包含内容 | 端口、内部信号、always 块、子模块实例 | 信号声明、modport、clocking block、断言、task/function |
| 例化方式 | 作为子模块在父模块中例化 | 作为端口在模块端口列表中声明 |
| 综合结果 | 产生硬件实例（门/触发器） | 被展开为独立信号——interface 本身不产生硬件 |
| 参数化 | 支持 parameter 和 generate | 支持 parameterized interface |
| 典型用途 | 功能单元（加法器、FIFO、控制器） | 总线协议封装（AXI、AHB、APB 信号组） |

interface 的核心价值在于**信号聚合（Signal Aggregation）**和**方向复用（Direction Multiplexing via modport）**：

```systemverilog
// ===== interface：将 AXI-Lite 总线信号打包为一个可复用的逻辑组 =====
interface axi_lite_if #(
    parameter ADDR_WIDTH = 32,                  // 地址总线位宽
    parameter DATA_WIDTH = 32                   // 数据总线位宽
) (
    input logic aclk,                           // 时钟（interface 可带时钟端口）
    input logic aresetn                         // 复位（低有效）
);
    // 写地址通道
    logic [ADDR_WIDTH-1:0] awaddr;              // 写地址
    logic                  awvalid;             // 写地址有效
    logic                  awready;             // 写地址就绪

    // 写数据通道
    logic [DATA_WIDTH-1:0] wdata;               // 写数据
    logic                  wvalid;              // 写数据有效
    logic                  wready;              // 写数据就绪

    // 读地址通道
    logic [ADDR_WIDTH-1:0] araddr;              // 读地址
    logic                  arvalid;             // 读地址有效
    logic                  arready;             // 读地址就绪

    // 读数据通道
    logic [DATA_WIDTH-1:0] rdata;               // 读数据
    logic                  rvalid;              // 读数据有效
    logic                  rready;              // 读数据就绪

    // ===== modport：定义不同模块视角下的信号方向 =====
    // master（管理器）：输出地址/数据/有效信号，输入就绪/响应信号
    modport master (
        output awaddr, awvalid, input awready,
        output wdata,  wvalid,  input wready,
        output araddr, arvalid, input arready,
        input  rdata,  rvalid,  output rready
    );

    // slave（从属器）：与 master 方向相反
    modport slave (
        input  awaddr, awvalid, output awready,
        input  wdata,  wvalid,  output wready,
        input  araddr, arvalid, output arready,
        output rdata,  rvalid,  input  rready
    );
endinterface
```

**关键收益**：一个 interface 实例替代了 N 个独立端口的声明。增加一个信号只需修改 interface 定义——所有使用该 interface 的模块自动同步，告别了逐个模块修改端口列表的噩梦。

## initial 与 always 的区别

| 维度 | initial | always |
|:---|:---|:---|
| 执行时机 | 仿真时间 0 开始，执行一次后永久终止 | 仿真时间 0 开始，敏感列表每次触发时重新执行，无限循环 |
| 可综合性 | **不可综合** | **可综合**（当用在 always_ff/always_comb 中时） |
| 典型用途 | 测试平台初始化（时钟初值、复位生成、激励施加） | RTL 设计中的时序/组合逻辑描述 |
| 等价硬件 | 无——硅片上电后没有"执行一次然后消失"的电路 | always_ff → 触发器组；always_comb → 组合逻辑门 |
| 数量限制 | 无（可在多个 initial 块） | 无（可在多个 always 块——模拟硬件并行） |

```systemverilog
// ===== RTL 设计：只能用 always（always_ff / always_comb）=====
// ✅ 寄存器：always_ff 描述 D 触发器
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)  q <= '0;
    else         q <= d;
end

// ===== 测试平台：用 initial 生成激励 =====
// ✅ 时钟生成：initial + forever（仿真专用）
initial begin
    clk = 1'b0;                                // 时间 0 设置时钟初值
    forever #5 clk = ~clk;                     // 每 5 时间单位翻转（100MHz）
end

// ✅ 复位生成：initial 块施加复位序列
initial begin
    rst_n = 1'b0;                              // 初始：复位有效
    #100 rst_n = 1'b1;                         // 100ns 后释放复位
end

// ✅ 测试激励：initial 块施加测试向量
initial begin
    @(posedge rst_n);                          // 等待复位释放
    repeat (10) @(posedge clk);                // 等待 10 个时钟周期
    // 施加激励...
end
```

**核心认知**：如果你在 RTL 中写 `initial`——停下来，这是错误的。RTL 中没有"仿真时间 0"这个概念——硬件上电后所有 always 块同时启动并永久运行。复位逻辑必须用 `always_ff @(posedge clk or negedge rst_n)` 实现，不能期望 `initial` 完成初始化。

## `$display`、`$monitor`、`$strobe` 的区别

三者都是仿真打印系统任务，**均不可综合**，但调度时机和触发机制截然不同：

| 特性 | `$display` | `$strobe` | `$monitor` |
|:---|:---|:---|:---|
| 调度区域 | Active 区 | Postponed 区 | Postponed 区 |
| 触发机制 | 执行到该语句时立即打印 | 时间步末尾所有事件稳定后打印 | 监控信号变化时自动打印 |
| 值的时间点 | 打印时刻的当前值 | 时间步结束后的最终稳定值 | 信号变化后的最终稳定值 |
| 调用次数 | 每次执行到该行时 | 每次执行到该行时 | **一次性设置**——持续监控，信号变化时自动触发 |
| 典型用途 | 调试打印、错误报告 | 检查时间步结束后的最终信号状态 | 持续监控关键总线/寄存器的变化 |

```systemverilog
// ===== 演示三种打印的差异 =====
module display_demo;
    logic [7:0] data;
    // --- $display：Active 区立即打印 ---
    // 执行到该行时打印 data 的当前值（可能还在变化中）
    initial begin
        data = 8'h00;                          // 时间 0：data = 0x00
        $display("[display] t=%0t data=0x%0h", $time, data);
        // 输出：[display] t=0 data=0x00

        #10 data = 8'hFF;                      // 时间 10：data = 0xFF
        $display("[display] t=%0t data=0x%0h", $time, data);
        // 输出：[display] t=10 data=0xFF

        // ===== $strobe：Postponed 区打印（时间步结束后的稳定值）=====
        data = 8'hAB;                          // 同一时间步：data 被改为 0xAB
        $strobe("[strobe] t=%0t data=0x%0h", $time, data);
        // 输出：[strobe] t=10 data=0xAB（打印的是最终值 0xAB，而非 0xFF）
    end

    // --- $monitor：持续监控 ---
    // 只需设置一次——每当 data 变化时自动打印
    initial begin
        $monitor("[monitor] t=%0t data=0x%0h", $time, data);
        // 输出（自动触发）：
        //   [monitor] t=0  data=0x00
        //   [monitor] t=10 data=0xFF
        //   [monitor] t=10 data=0xAB
    end
endmodule
```

**核心区别**：`$display` 看到的是"瞬时值"（Active 区）、`$strobe` 看到的是"最终值"（Postponed 区）、`$monitor` 是"持续监控"——一旦设置，每当监控信号变化就自动打印。在调试 race condition 时，`$strobe` 比 `$display` 更能反映信号在时间步结束后的真实状态。**三者均不可综合——综合时会自动被忽略。**

## SystemVerilog 中 program 与 module 的区别

`program` 块是 SystemVerilog 引入的**测试平台专用容器**，旨在解决 Verilog 测试平台中经典的**竞争条件（Race Condition）**问题。

| 维度 | module | program |
|:---|:---|:---|
| 调度区域 | Active 区（与 RTL 设计同一区域） | **Re-Active 区**（在 Active/Inactive/NBA/Observed 之后） |
| 可综合性 | 可综合（设计模块） | **不可综合**（纯验证用途） |
| 内部 always | 所有 always 类型 | 仅允许 `initial` 块（SV 中将 program 内的过程块都视为 initial） |
| 设计/验证边界 | 模糊——RTL 设计和测试平台混在同一调度区域 | 明确——测试平台在 RTL 时间步完全稳定后才采样/驱动 |
| 典型用途 | RTL 设计 + 通用测试平台 | **UVM 测试平台顶层容器** |

```systemverilog
// ===== program：测试平台顶层——消除 race condition =====
program automatic testbench (
    input logic clk,                           // 时钟（从 DUT 输入）
    output logic rst_n                         // 复位（输出到 DUT）
);
    // program 内所有 initial 块在 Re-Active 区执行
    // 此时 RTL 的所有 Active/NBA 更新已经完成——信号是稳定的
    initial begin
        rst_n = 1'b0;
        #100 rst_n = 1'b1;
        @(posedge clk);                        // 采样的是稳定后的时钟值
        // 在 Re-Active 区驱动激励，下一时间步进入 Active 区被 DUT 采样
    end
endprogram
```

**为什么需要 program？** 在传统 Verilog 中，测试平台的 `initial` 块和 RTL 的 `always` 块都在 Active 区执行——执行顺序不确定。同一个时钟沿，测试平台可能在 RTL 更新前采样（读到旧值）或更新后采样（读到新值）——这是 race condition。program 的 Re-Active 区解决方案保证了：RTL 所有信号在一个时间步内完全稳定后，测试平台才进行采样和驱动。

## parameter 与 `define 宏的区别

| 维度 | `define | parameter |
|:---|:---|:---|
| 本质 | **预处理宏**——编译前进行文本替换 | **编译时常量**——属于语言的类型系统 |
| 作用域 | **全局**（从定义位置到文件末尾或 `undef） | **局部**（模块/interface/program/package 内部） |
| 类型检查 | **无**——纯文本替换，无类型信息 | **有**——可指定类型 `parameter logic [7:0] W = 8` |
| 重载方式 | 编译命令行 `+define+NAME=VALUE` | 实例化时 `#(.PARAM(value))` 命名参数覆盖 |
| 在 generate 中使用 | 有限支持（预处理器在 generate 之前展开） | **完全支持**——generate-if/case 的条件判断 |
| 调试可见性 | 无（宏名在编译后被替换，波形中不可见） | 有（parameter 是编译单元内的具名常量） |

**核心区别**：`define 是文本替换工具——在编译的**预处理阶段**进行字面替换，没有类型、没有作用域、没有调试信息。parameter 是**语言的一部分**——有类型、有局部作用域、支持命名重载、在波形查看器中可见。RTL 编码中应**优先使用 parameter**，仅在需要条件编译（`ifdef/`ifndef）或头文件保护时才使用 `define。

```systemverilog
// ===== `define：预处理宏 =====
`define DATA_WIDTH 32                          // 全局宏——所有后续代码中 DATA_WIDTH → 32
`define SIMULATION                             // 条件编译标志
module test;
    logic [`DATA_WIDTH-1:0] bus;               // 预处理后：logic [32-1:0] bus;
    `ifdef SIMULATION
        initial $display("Simulation mode");   // 仿真时包含此代码
    `endif
endmodule

// ===== parameter：模块级编译时常量 =====
module adder #(
    parameter int WIDTH = 8                    // 参数：类型为 int，默认值 8
) (
    input  logic [WIDTH-1:0] a, b,
    output logic [WIDTH-1:0] sum
);
    assign sum = a + b;
endmodule
// 实例化时重载：adder #(.WIDTH(16)) u_adder16 (.*);
```

**localparam** 与 parameter 类似但**不可在实例化时被重载**——用于声明模块内部实现细节常量：

```systemverilog
localparam IDLE = 2'b00;                       // 状态编码——模块内部使用，不可被外部重载
localparam TIMEOUT_CYCLES = 1000;              // 超时阈值——内部常量
```

## case、casez、casex 的区别及使用注意事项

| 特性 | `case` | `casez` | `casex` |
|:---|:---|:---|:---|
| 匹配规则 | **精确匹配**：所有位必须相等 | `?`/`z`/`Z` 视为 **don't-care**（通配） | `?`/`z`/`Z`/`x`/`X` 均视为 **don't-care** |
| 综合行为 | 并行 MUX 树（互斥 case 项时） | 优先级编码器（带 don't-care 位时） | 同 casez，但更危险 |
| 推荐程度 | **推荐**——用于互斥条件 | **谨慎使用**——适合优先级编码器 | **不推荐/禁止**——x-乐观性导致仿真综合不匹配 |

```systemverilog
// ===== case：精确匹配（推荐默认选择）=====
always_comb begin
    case (sel)
        2'b00:  out = a;                       // sel == 00 时选择 a
        2'b01:  out = b;                       // sel == 01 时选择 b
        2'b10:  out = c;                       // sel == 10 时选择 c
        2'b11:  out = d;                       // sel == 11 时选择 d
        default: out = '0;                      // 防御性 default：处理 X/Z 和未覆盖值
    endcase
end

// ===== casez：don't-care 匹配（优先级编码器）=====
// ? 和 z 被当作通配符——匹配时不关心该位的值
always_comb begin
    casez (irq)                                // irq 为中断请求向量
        4'b???1:  prio = 2'd0;                 // irq[0]=1 → 最低优先级
        4'b??10:  prio = 2'd1;                 // irq[1]=1, irq[0]=0 → 优先级 1
        4'b?100:  prio = 2'd2;                 // irq[2]=1, 低位为 0 → 优先级 2
        4'b1000:  prio = 2'd3;                 // irq[3]=1, 低位为 0 → 最高优先级
        default:  prio = 2'd0;
    endcase
end

// ===== casex：危险——仿真与综合可能不一致 =====
// casex 将 X 和 Z 都视为 don't-care——X-乐观性掩盖 bug
always_comb begin
    casex (state)
        2'b1x:  next = A;                      // 仿真中 state=2'b1x 时匹配——但综合工具认为 X 不会出现
        2'b0x:  next = B;
        default: next = C;
    endcase
end
// 推荐替代：casez + ? 替代 casex
always_comb begin
    unique casez (state)
        2'b1?:  next = A;                      // 仅 ? 为 don't-care，X 不会误匹配
        2'b0?:  next = B;
        default: next = C;
    endcase
end
```

**casex 被禁止的三大原因**：
1. **X-乐观性（X-Optimism）**：仿真中 X 匹配 don't-care 分支被视为"成功"——掩盖了未初始化或信号冲突的 bug
2. **仿真与综合不一致**：综合工具将 X 优化为 don't-care 逻辑——仿真中 X 本应触发报错，却被 casex 静默吞没
3. **IEEE 1800-2017 推荐**：LRM 建议用 `casez` 或 `case (...) inside` 替代 `casex`

**unique case / priority case 语法增强**：

```systemverilog
// unique case：断言所有 case 项互斥，仿真中多匹配或无匹配时报警
unique case (sel)
    2'b00: out = a;
    2'b01: out = b;
    default: out = '0;
endcase

// priority case：断言至少一项匹配，按书写顺序建立优先级
priority casez (irq)
    4'b???1: prio = 2'd0;
    4'b??10: prio = 2'd1;
    4'b?100: prio = 2'd2;
    4'b1000: prio = 2'd3;
endcase
```

## 阻塞赋值（=）与非阻塞赋值（<=）的深度解析

### 仿真调度队列（Stratified Event Queue）

Verilog/SystemVerilog 仿真器采用分层事件队列（IEEE 1800-2017 Section 4），每个时间步划分为多个调度区域（Region）：

| Region | 名称 | 执行内容 |
|:---|:---|:---|
| **Preponed** | 采样前 | 采样信号值（供断言和覆盖率使用） |
| **Active** | 激活区 | 阻塞赋值 `=`、`$display`、连续赋值 `assign` RHS 计算 |
| **Inactive** | 非激活区 | `#0` 延迟事件 |
| **NBA** | 非阻塞更新区 | `<=` 左侧更新（右侧已在 Active 区计算完） |
| **Observed** | 观测区 | 并发断言求值 |
| **Re-Active** | 反应区 | program 块中代码执行 |
| **Re-NBA** | 反应非阻塞更新区 | program 中的 `<=` 更新 |
| **Postponed** | 推迟区 | `$strobe`、`$monitor` 打印 |

**非阻塞赋值（<=）的两阶段执行**：

1. **Active 区**：计算所有 `<=` 语句的右侧表达式（RHS），将结果暂存于临时队列
2. **NBA 区**：将所有暂存的 RHS 值统一更新到左侧变量（LHS）

### 为什么时序逻辑必须用非阻塞赋值？

物理 D 触发器在时钟沿同时采样输入端——非阻塞赋值的两阶段机制精确建模了这一行为：

```systemverilog
// ✅ 非阻塞赋值 —— 所有寄存器"看到"的是时钟沿时刻的旧值
always_ff @(posedge clk) begin
    q1 <= d;                                   // q1 的新值 = 当前 d 的旧值
    q2 <= q1;                                  // q2 的新值 = 当前 q1 的旧值（不是刚算出的新值！）
end
// 硬件行为：d → FF1 → q1 → FF2 → q2（移位寄存器——两级延迟）

// ❌ 阻塞赋值 —— 赋值立即生效，后续语句读到新值
always_ff @(posedge clk) begin
    q1 = d;                                    // q1 立即变为 d
    q2 = q1;                                   // q2 立即变为"新 q1" = d（跳过了一级寄存器！）
end
// 综合工具可能将 q1 和 q2 合并——丢失一级流水线
```

### 混用阻塞和非阻塞的后果

在同一 always 块中混用 `=` 和 `<=` 是 **RTL 编码的严重错误**：
1. **仿真结果依赖语句顺序**——`=` 在 Active 区立即生效，`<=` 在 NBA 区才更新，两者间存在竞态
2. **综合工具报错或警告**——DC/Genus/Vivado 标记混用为严重 lint 错误
3. **仿真与综合不一致（Sim-Synth Mismatch）**——仿真波形和门级网表行为可能完全不同

```systemverilog
// ❌ 同一 always 块中混用 = 和 <=
always_ff @(posedge clk) begin
    tmp = a & b;                               // 阻塞：Active 区立即生效
    q  <= tmp;                                 // 非阻塞：NBA 区更新
    // 综合 lint：[WARN] Mixed blocking and non-blocking assignments
end
```

**正确做法**：`always_comb` 中只用 `=`，`always_ff` 中只用 `<=`，绝不混用。

## 关键要点

- **logic 类型统一 wire/reg**：logic 默认单驱动约束，多驱动场景用 wire/tri；logic 默认值为 X，便于仿真时暴露未初始化信号
- **always_ff/comb/latch 语义校验**：编译时检查消除敏感列表不全、锁存器意外推断等 Verilog 常见陷阱
- **非阻塞赋值（<=）在 NBA 区统一更新**：两阶段机制（Active 计算 RHS + NBA 更新 LHS）精确建模物理 D 触发器的并行采样——时序逻辑混用 `=` 会破坏仿真与硬件的一致性
- **wire/reg 命名误导，logic 统一语义**：reg 可能综合为组合逻辑——判断标准是 always 块敏感列表（边沿→寄存器，电平→组合/锁存器）；双向端口必须用 wire（多驱动场景）
- **task vs function 本质差异在时序控制权**：function 必须在零仿真时间内完成（禁止 `#`/`@`/`wait`）；可综合子集中两者等价（均无时序控制）
- **interface 是信号聚合容器，module 是功能单元**：interface + modport 实现总线级复用，增加信号只需修改一处——告别逐个模块改端口列表
- **initial 仅限测试平台，RTL 只用 always**：initial 在仿真时间 0 执行一次后终止——硅片上没有"执行一次然后消失"的电路
- **`$display`(Active)/`$strobe`(Postponed)/`$monitor`(持续监控)**：三者在仿真调度队列的不同区域执行——调试 race condition 时必须用 `$strobe` 观察最终稳定值
- **`program` 的 Re-Active 区解决 TB-RTL race condition**：测试平台在 RTL 完全稳定后才采样/驱动——UVM 验证环境的标准顶层容器
- **`parameter 优于 `define**：有类型检查、局部作用域、命名重载、波形可见——仅条件编译（`ifdef）时用 `define
- **casex 被禁止，用 casez 或 case...inside 替代**：X-乐观性导致仿真 bug 被静默吞没——仿真综合不一致是最危险的缺陷类型
- **unique case 和 priority case 提供语义校验**：编译器和仿真器可据此检测多匹配/无匹配的违反——是裸 case 的类型安全升级
- **`$clog2()` 可综合系统函数**：RTL 中计算位宽的必备工具——替代手动 `define 宏，避免对数舍入错误
- **automatic task/function 支持递归和可重入**：每次调用分配独立存储空间——静态（static）task/function 的内部变量在多次调用间共享

## 与其他概念的关系

- [[rtl-design/concepts/Verilog-HDL|Verilog HDL]] — SystemVerilog 作为 Verilog 的超集，对比 wire/reg 与 logic、always 与 always_ff/always_comb 的核心差异，以及阻塞/非阻塞赋值的仿真调度语义
- [[rtl-design/concepts/编码风格|RTL 编码风格]] — 基于 SV 的可综合编码规范，always_ff 模板、interface 使用约定、parameter 优先于 `define 等实践
- [[rtl-design/concepts/时序逻辑|时序逻辑]] — always_ff 与 `<=` 如何精确描述 D 触发器并行行为，以及 NBA 区更新机制
- [[rtl-design/concepts/有限状态机|状态机设计]] — enum + unique case + always_comb/always_ff 三进程模板实现 Moore/Mealy FSM
- [[rtl-design/concepts/FIFO设计|FIFO 设计]] — 同步/异步 FIFO 的空满判断、parameter 参数化深度位宽、FWFT 模式等 RTL 实现技术
- [[rtl-design/concepts/跨时钟域设计|跨时钟域设计（CDC）]] — interface 在 CDC 边界的时钟域桥接、program 块在跨时钟域验证中的应用