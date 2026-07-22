---
type: concept
aliases:
  - Pipeline Design_流水线设计
  - Pipeline Design
  - Pipelining
tags:
  - asic
  - rtl
  - pipeline
  - throughput
source_spec: "Hennessy & Patterson, Computer Architecture: A Quantitative Approach Ch.3; Weste & Harris, CMOS VLSI Design Ch.11"
---
# Pipeline Design — RTL 流水线设计

流水线（Pipeline）是提升数字电路吞吐率（Throughput）的核心微架构技术——将一个复杂的组合操作拆分为多个较短的阶段（Stage），相邻阶段之间插入流水线寄存器（Pipeline Register），使多个操作可以在不同阶段重叠执行，如同工厂装配线。流水线的核心权衡是：**吞吐率提升的代价是延迟（Latency）增加**（因寄存器插入的时钟周期开销）和面积/功耗增加（因流水线寄存器和握手逻辑的触发器开销）。流水线不仅用于处理器（经典的 5 级 RISC 流水线：取指-译码-执行-访存-写回），也是高性能算术单元（流水线乘法器、浮点加法器）、网络包处理器和图像处理管道的标准设计模式。

## 原理

### 吞吐率与延迟的权衡

流水线的性能指标由三个参数定义。**延迟（Latency）**：单个操作从进入流水线到完成的总时钟周期数，等于流水线级数 $N$。**吞吐率（Throughput）**：单位时间内完成的操作用数量——对于 $K$ 级流水线，理想吞吐率为每时钟周期 1 个操作（达到稳态后）。相比于非流水线的组合逻辑实现（吞吐率为 $1/K$ 每周期），流水线吞吐率提升 $K$ 倍。

关键公式：非流水线组合逻辑延迟 $T_D$ 被拆分为 $N$ 个阶段，每阶段延迟 $T_D/N$（理想均分），则最大时钟周期 $T_{clk} = T_D/N + T_{setup} + T_{clk2q}$，吞吐率 = $1/T_{clk}$。实际拆分中受制于逻辑单元的不均匀性——某些路径天然较长（如乘法器的进位链），均匀拆分需要额外组合逻辑平衡。

### 寄存器切片（Register Slicing）

寄存器切片是流水线化的基本操作——在组合逻辑中间插入寄存器以打断长路径。切片的艺术在于选择插入位置使各阶段延迟尽量均衡——如果某一阶段的逻辑深度是其他部分的 2 倍，则该阶段决定了整个流水线的时钟频率（最弱链路原理）。自动流水线化工具（如 Synopsys DC 的 `pipeline_design`）可在指定延迟预算的条件下自动分段插入寄存器，但手动切片通常产生更可预测的结构。

### Stall 和 Flush 协议

流水线必须在外部事件打断正常流时维护数据完整性。**Stall（停顿）**：当下游无法接收数据时（如缓存未命中、总线仲裁等待），流水线必须冻结所有阶段——将所有阶段寄存器使能关闭，保持当前数据不变。Stall 信号（通常为低电平有效的寄存器使能或时钟门控信号）从下游传播到上游，每一级在下一级准备好之前暂停。

**Flush（冲刷）**：当指令无效时（如分支预测失败、中断），必须清除流水线中已完成部分操作的无效数据——将对应阶段的 valid 位清零或直接将流水线寄存器设置为 NOP（No-Operation）编码。Flush 信号必须同时清除多个流水级的数据，需要确保不会误清除正在执行的有效操作。

Stall 和 Flush 是流水线控制器的两个核心原语——Stall 是"等待"，Flush 是"放弃"。两者在时序路径上的优先级需要明确定义：当 Stall 和 Flush 同时发生时，典型优先级是 Flush 优先（取消的操作不需要保存）。

### Valid-Ready 背压机制

Valid-Ready（或称 AXI-Stream 握手）是流水线间数据传输的标准接口协议。发送端驱动 `valid` 信号指示数据有效，接收端驱动 `ready` 信号指示可以接收。当 `valid && ready` 在同一时钟沿同时为真时，数据在发送端和接收端之间完成一次传输（Handshake）。如果接收端未就绪（ready=0），发送端必须保持 valid 和数据稳定——这就是背压（Backpressure）。

Valid-Ready 接口的正确实现需要考虑几个关键细节：a) ready 信号在流水线中必须可组合——`ready_stage_N = ready_stage_N+1 || !valid_stage_N+1`（下游有空位或数据未被占用的条件下拉高 ready）；b) 全流水线级联的 Valid-Ready 链从末端到前端的级别数决定了背压的传播延迟——过长的流水线可能需要在 ready 路径上插入寄存器（Skid Buffer）；c) valid 和 ready 的变化都必须在时钟沿被采样，避免组合环（Combinational Loop）。

### 转发（Forwarding）与数据冒险

流水线中的数据冒险（Data Hazard）发生在后续指令需要前面指令结果，但该结果尚未写入寄存器堆时。**转发（Forwarding/Bypassing）**通过 MUX 将从流水线后级（执行阶段输出、访存阶段输出）的计算结果直接旁路到前级（执行阶段输入），绕过寄存器堆写入再读取的延迟。转发将 RAW（Read-After-Write）冒险的处理周期从等待写回到寄存器堆的多周期减少到在流水线中插入 0-1 个气泡。转发的 MUX 增加了解码执行路径的组合逻辑延迟，需要仔细评估时序影响。

**结构冒险（Structural Hazard）**发生在两个操作同时竞争同一硬件资源时（如单端口寄存器堆的读端口数不足、除法器未流水线化）。解决方案包括：复制资源（增加读端口）、时分复用（Stall 一个操作等待资源空闲）、或架构避免（分离指令和数据缓存）。

### 流水线乘法器示例

以 16x16 位流水线乘法器为例展示流水线化技术。非流水线 Booth-Wallace 乘法器延迟约 $T_{booth} + T_{wallace\_tree} + T_{final\_adder}$。将其分为 3 级流水线：第一级（Booth 编码和部分积生成），第二级（Wallace 树压缩到两个部分和），第三级（最终加法器）。每级插入 32 位寄存器，三级流水线吞吐率达到每周期 1 次乘法，而非流水线版本约每 3 周期 1 次。面积开销约为三级寄存器（96 个 D-FF）加上必要的 Stall/Flush 控制逻辑（约 30-50 个等效门）。

### Skid Buffer 与反压传播延迟

当 Valid-Ready 流水线级数较长（>10 级）时，ready 信号从流水线末端逐级向前传播的组合路径可能成为新的时序瓶颈——每一级 ready 取决于下一级的 ready 和 valid 状态，形成 $\mathcal{O}(N)$ 的进位链式延迟。**Skid Buffer（滑动缓冲）**是解决长流水线反压传播延迟的标准技术——在 ready 路径上插入两级寄存器（Skid Buffer），将 ready 的传播延迟从组合路径转化为可时序约束的寄存器到寄存器路径。

Skid Buffer 的双寄存器结构：当接收端反压（ready=0）时，数据首先被缓存在第一个 Skid 寄存器中；如果反压持续，数据进一步被缓存到第二个 Skid 寄存器（两级深度的弹性缓冲区）。两级 Skid Buffer 允许 ready 信号在最坏情况下有 2 个周期的延迟（两级寄存器链的 clk2q + 组合逻辑），而非一长串组合逻辑的聚合延迟。Skid Buffer 的容量通常为 2（两级深度），足以覆盖绝大多数的流水线反压延迟需求——对于极端长的流水线（如网络包处理器的 32 级流水线），可在每 8-10 级之间插入一个 Skid Buffer 将 ready 路径分段。

**Skid Buffer 可综合实现的核心逻辑**：

```systemverilog
// 两级 Skid Buffer：在 ready 路径上插入寄存器以打断长组合链
module skid_buffer #(parameter WIDTH = 32) (
    input  logic             clk, rst_n,
    input  logic             i_valid, i_data [WIDTH-1:0],
    output logic             i_ready,
    output logic             o_valid, o_data [WIDTH-1:0],
    input  logic             o_ready
);
    logic [WIDTH-1:0] skid_data;
    logic             skid_valid;  // Skid buffer 中有缓存数据

    assign i_ready = o_ready || !o_valid;  // 总在可接收或下游空闲时准备好

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_valid    <= 1'b0;
            skid_valid <= 1'b0;
        end else begin
            if (i_ready) begin
                if (o_ready || !o_valid) begin
                    o_valid <= i_valid;
                    o_data  <= i_data;
                end else begin
                    skid_valid <= i_valid;
                    skid_data  <= i_data;
                end
            end
            if (o_ready && skid_valid) begin
                o_valid    <= 1'b1;
                o_data     <= skid_data;
                skid_valid <= 1'b0;
            end
        end
    end
endmodule
```

## 关键要点

- 吞吐率提升（$K$ 倍）以延迟增加（$K$ 周期）和寄存器面积/功耗为代价——流水线级数 $K$ 的选定是全系统时序和面积权衡的结果
- 寄存器切片的最优位置是使各阶段延迟均衡——最长阶段决定整个流水线频率，"最弱链路"原则驱动切片优化
- Stall 和 Flush 是流水线控制的核心原语——Stall 冻结数据（等待），Flush 清除无效数据（放弃），同时发生时 Flush 优先
- Valid-Ready 背压机制是流水线级联的标准接口——ready 必须从下游到上游可组合传递，长流水线需考虑 ready 传播的时序收敛
- 转发（Forwarding）是处理数据冒险的关键技术——通过旁路 MUX 将后级结果直接馈入前级，将 RAW 冒险惩罚降至 0-1 个周期
- 结构冒险通过资源复制（多端口）、时分复用（Stall）或架构避免（分离 I-Cache/D-Cache）解决
- 流水线乘法器的典型分割为 Booth 编码 -> 部分积压缩 -> 最终加法，每级寄存使得吞吐率达到每周期 1 次乘法
- 流水线寄存器的时钟门控（当 Stall 时）可显著降低流水线动态功耗——Stall 期间各阶段输出数据不变，门控时钟消除无意义的触发器翻转
- Skid Buffer（两级弹性缓冲）是解决长流水线反压 propagation 延迟的标准技术——在 ready 路径上插入寄存器，将 $\mathcal{O}(N)$ 组合延迟转化为可约束的寄存器到寄存器路径
- 流水线的"气泡"（Bubble）是指由于 Stall 或 Flush 导致的流水线空闲周期——气泡率（Bubble Rate）是衡量流水线效率的关键指标，分支预测失败是处理器流水线气泡的主要来源
- 流水线寄存器布局中需要物理上靠近其所分隔的组合逻辑块——流水线寄存器的物理分布直接影响时钟树延迟平衡和时序收敛的难度

## 与其他概念的关系

- [[rtl-design/concepts/sequential-logic|时序逻辑]] — 流水线寄存器本质是 D-FF，流水线最大频率由最慢阶段的 setup/clk2q 决定。时钟树平衡和寄存器物理布局直接影响流水线各阶段间的时钟偏斜（Clock Skew）预算分配
- [[rtl-design/concepts/fsm-design|FSM 设计]] — 流水线控制器（Stall/Flush 逻辑）本质上是 FSM+Datapath 分离设计的典型实例。FSM 的状态转换（如 IDLE -> ACTIVE -> STALL -> FLUSH）直接控制流水线寄存器的使能和清零
- [[rtl-design/concepts/arithmetic-circuits|算术电路]] — 高性能算术单元（乘法器、加法器、除法器）广泛使用流水分割以提升吞吐率。乘法器从 Booth 编码到 Wallace 树到最终加法的三阶段分割是流水线在数据通路中最直接的应用
- [[architecture/concepts/pipelining|体系结构流水线]] — 处理器级流水线与 RTL 级流水的接口对齐——处理器微架构决策（如指令发射宽度、重排序缓冲区深度）驱动 RTL 流水线的划分方式和握手协议设计
