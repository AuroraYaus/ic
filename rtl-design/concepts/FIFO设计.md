---
type: concept
aliases:
  - FIFO Design_FIFO设计
  - 同步FIFO
  - 异步FIFO
  - FWFT FIFO
tags:
  - asic
  - rtl
  - fifo
  - verilog
  - systemverilog
source_spec: "Cummings, Simulation and Synthesis Techniques for Asynchronous FIFO Design (SNUG 2002); IEEE 1800-2017; Xilinx UG473 FIFO Generator"
queries: 1
---
# FIFO 设计

FIFO（First-In First-Out，先进先出队列）是数字IC设计中使用最广泛的数据缓冲结构之一，用于在数据生产者（Producer）和消费者（Consumer）之间提供速率解耦和弹性缓冲。FIFO 的核心设计挑战是空满标志（Empty/Full Flag）的生成——指针比较逻辑需要在写满后阻止写入、读空后阻止读出，同时保证标志的及时性以避免数据丢失或重复读出。FIFO 分为两大类：**同步 FIFO（Synchronous FIFO）** 读写共用同一时钟，设计相对简单；**异步 FIFO（Asynchronous FIFO）** 读写时钟不同——需要引入格雷码指针同步和跨时钟域（CDC）处理，是设计验证的难点之一。

## 同步 FIFO 设计

### 空满判断方法

同步 FIFO 的空满判断核心是读写指针的比较。基本方法有几种：

**1. 额外高位法（MSB 圈数标记）**：读写指针位宽为 `$clog2(DEPTH)+1`，多出的最高位（MSB）用于标记指针绕回的"圈数"。当低地址位相等时：MSB 相同表示读写指针完全一致（FIFO 空），MSB 不同表示写指针比读指针多绕了一圈（FIFO 满）。这是最常用的方法，已在 Verilog-HDL.md 中给出完整实现。

**2. 计数器法**：维护一个 `data_count` 寄存器，每次写操作递增、读操作递减。`data_count == 0` 为空，`data_count == DEPTH` 为满。优点是可以直接获得当前 FIFO 中的数据数量（Occupancy），缺点是需要额外的加减法器和寄存器，且计数器值与指针在仿真中可能出现不一致。

**3. 寄存器标志位法**：在读写指针相等时额外维护一个 `direction` 标志——记录最后一次使指针相等的是读操作还是写操作。如果是读操作（追上了写指针）→ 空；如果是写操作（追上了读指针）→ 满。

下面是基本同步 FIFO 的完整代码实现（已在 Verilog-HDL.md 中给出核心版本，此处补充带数据计数器的完整版本）：

```systemverilog
// ============================================================
// 带数据计数器（Data Count）的深度16、位宽8同步FIFO
// ============================================================
module sync_fifo #(
    parameter DEPTH = 16,                         // FIFO 深度（可参数化）
    parameter WIDTH = 8                           // 数据位宽（可参数化）
) (
    input  logic             clk,                 // 时钟信号（上升沿采样）
    input  logic             rst_n,               // 异步复位（低电平有效，_n 后缀）
    input  logic             wr_en,               // 写使能（1=写入有效，0=无操作）
    input  logic             rd_en,               // 读使能（1=读出有效，0=无操作）
    input  logic [WIDTH-1:0] wr_data,             // 写入数据（WIDTH 位宽）
    output logic [WIDTH-1:0] rd_data,             // 读出数据（WIDTH 位宽）
    output logic             empty,               // 空标志（1=FIFO 为空，禁止读）
    output logic             full,                // 满标志（1=FIFO 为满，禁止写）
    output logic [$clog2(DEPTH):0] data_count     // 数据计数器（当前存储量，0~DEPTH）
);
    // ===== 存储器阵列 =====
    // logic [WIDTH-1:0]：每个存储单元 WIDTH 位宽
    // [0:DEPTH-1]：DEPTH 个存储单元（unpacked 维度）
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    // ===== 读写指针 =====
    // 位宽 $clog2(DEPTH)+1：高1位用于圈数标记，低 $clog2(DEPTH) 位用于SRAM寻址
    logic [$clog2(DEPTH):0] wr_ptr, rd_ptr;

    // ===== 时序逻辑：指针更新与数据存取 =====
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr     <= '0;                     // 写指针复位
            rd_ptr     <= '0;                     // 读指针复位
            data_count <= '0;                     // 数据计数清零
        end else begin
            // ----- 写操作：FIFO 未满且写使能有效 -----
            if (wr_en && !full) begin
                // 低 $clog2(DEPTH) 位作为 SRAM 写入地址
                mem[wr_ptr[$clog2(DEPTH)-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;          // 写指针自增（位宽自动回绕）
            end

            // ----- 读操作：FIFO 非空且读使能有效 -----
            if (rd_en && !empty) begin
                // 低 $clog2(DEPTH) 位作为 SRAM 读出地址
                rd_data <= mem[rd_ptr[$clog2(DEPTH)-1:0]];
                rd_ptr <= rd_ptr + 1'b1;          // 读指针自增（位宽自动回绕）
            end

            // ----- 数据计数更新（组合逻辑也可，此处用时序保证同步）-----
            // case 优先级：同时读写时 data_count 不变（一进一出）
            unique case ({(wr_en && !full), (rd_en && !empty)})
                2'b10: data_count <= data_count + 1'b1;  // 只写不读：计数+1
                2'b01: data_count <= data_count - 1'b1;  // 只读不写：计数-1
                default: ;                                 // 同时或都不：计数不变
            endcase
        end
    end

    // ===== 组合逻辑：空满标志生成 =====
    // empty：读写指针完全相等 → 所有数据已被读出
    assign empty = (wr_ptr == rd_ptr);

    // full：低地址位相等 且 最高位（圈数标记）不同
    // 写指针比读指针多绕一整圈 → FIFO 被写满
    assign full  = (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0])
                 && (wr_ptr[$clog2(DEPTH)]       != rd_ptr[$clog2(DEPTH)]);

endmodule
```

### Almost Full / Almost Empty

在实际系统中，FIFO 消费者或生产者可能需要**提前预警**以响应背压（Backpressure）。**Almost Full**（几乎满）和 **Almost Empty**（几乎空）标志在 Full 或 Empty 发生前的 N 个周期提前置位：

```systemverilog
// ===== Almost Full / Almost Empty 标志 =====
// 定义阈值：剩余空间 ≤ ALMOST_FULL_THRESH 时触发 almost_full
//          数据量 ≤ ALMOST_EMPTY_THRESH 时触发 almost_empty
localparam ALMOST_FULL_THRESH  = 2;              // 剩余 2 个空位时触发（提前 2 个周期预警）
localparam ALMOST_EMPTY_THRESH = 2;              // 仅剩 2 个数据时触发

// almost_full：DEPTH - data_count ≤ ALMOST_FULL_THRESH
// 即：剩余空间不足
assign almost_full  = (DEPTH - data_count <= ALMOST_FULL_THRESH);

// almost_empty：data_count ≤ ALMOST_EMPTY_THRESH
// 即：可用数据不足
assign almost_empty = (data_count <= ALMOST_EMPTY_THRESH);
```

这些标志广泛用于 AXI Stream 总线背压管理、DMA 控制器的描述符预取，以及视频处理流水线的帧缓冲管理。

### 非 2 幂深度 FIFO

FIFO 深度为 2 的幂次（16, 32, 64...）时，指针加法器的溢出自动产生自然回绕（rollover），无需额外的取模逻辑。当深度为**非 2 幂**（如 DEPTH=12）时，指针不能依赖自然溢出回绕——需要显式的取模逻辑：

```systemverilog
// ===== 非2幂深度的指针更新 =====
// 方法1：带比较的回绕——当指针达到 DEPTH-1 时归零
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= '0;
    end else if (wr_en && !full) begin
        mem[wr_ptr] <= wr_data;                   // 直接用 wr_ptr 寻址（不需要截低位）
        if (wr_ptr == DEPTH - 1)
            wr_ptr <= '0;                         // 到达末尾：回绕到 0
        else
            wr_ptr <= wr_ptr + 1'b1;              // 未到末尾：正常自增
    end
end

// 方法2：使用取模运算符（综合工具通常能优化，但需要确认）
// wr_ptr <= (wr_en && !full) ? (wr_ptr + 1'b1) % DEPTH : wr_ptr;

// 空满判断也随之改变——不能用 MSB 圈数法
logic [$clog2(DEPTH+1)-1:0] wr_cnt;               // 单独的写计数（追踪写入次数）
logic [$clog2(DEPTH+1)-1:0] rd_cnt;               // 单独的读计数（追踪读出次数）
assign empty = (wr_cnt == rd_cnt);                 // 写入总数 = 读出总数 → 空
assign full  = (wr_cnt - rd_cnt == DEPTH);         // 差值 = 深度 → 满
```

非 2 幂深度的代价是空满判断需要维护独立的读写计数器（而非仅依赖地址指针），增加了面积和关键路径延迟。**在 ASIC/FPGA 设计中通常建议将 FIFO 深度向上调整为最近的 2 的幂**（如 12→16），除非面积约束极为严格。

### FWFT FIFO（First Word Fall Through）

标准 FIFO 在读使能（rd_en）置位后的下一个时钟周期才将数据输出到 rd_data 端口——数据需要"穿过"输出寄存器。**FWFT FIFO**（First Word Fall Through，首字直通）在读使能置位的**同一周期**即将首个数据呈现在输出端口——数据直接从 SRAM 读出并驱动到输出，不经过输出寄存器：

```systemverilog
// ===== FWFT FIFO 关键差异 =====
// 标准 FIFO：rd_en 置位 → next cycle rd_data 有效（寄存输出）
//   always_ff @(posedge clk) begin
//       if (rd_en && !empty) rd_data <= mem[rd_ptr];
//   end

// FWFT FIFO：rd_data 持续输出当前读指针指向的数据（组合输出）
//   当 rd_en=1 时，rd_ptr 更新的同时，下一个数据立即出现在输出
assign rd_data = mem[rd_ptr[$clog2(DEPTH)-1:0]];
// 注意：empty 信号在 FWFT 模式下需要特殊处理——
// 当数据被读出后，下一个数据"直通"到输出端口，
// empty 判断应基于"读指针追上写指针"而非"是否刚读了最后一个"
```

| 特性 | 标准 FIFO | FWFT FIFO |
|:---|:---|:---|
| 读延迟 | 1 周期（寄存器输出） | 0 周期（组合输出） |
| 输出时序路径 | 短（寄存器→寄存器） | 长（SRAM→组合→下游逻辑） |
| 适用场景 | 通用缓冲、跨时钟域 | 低延迟数据通路、AXI 读通道 |
| 空标志语义 | 无可用数据 | 同上，但 rd_data 在 empty 期间无效 |

## 同步 FIFO vs 异步 FIFO

| 维度 | 同步 FIFO | 异步 FIFO |
|:---|:---|:---|
| 读写时钟 | 同一时钟 | 不同时钟（频率/相位独立） |
| 指针同步 | 无需同步（同时钟域） | 需要格雷码 + 2-FF 同步器跨时钟域 |
| 空满判断 | 直接比较指针 | 同步后的格雷码比较（有延迟） |
| 空满精度 | 精确（零周期延迟） | 保守（满标志提前、空标志延迟） |
| CDC 风险 | 无 | 亚稳态窗口 → 需要 2-FF + 格雷码保护 |
| 典型场景 | 流水线级间缓冲 | 跨时钟域数据接口（AXI4-Stream CDC） |

异步 FIFO 的核心技术：格雷码（Gray Code）编码保证了指针跨时钟域传输时，相邻值只有 1 位翻转——即使同步器因亚稳态捕获了旧值，结果也只是"少计一圈"，不会出现多位同时翻转导致的非法中间状态。这使得满标志可能提前（full asserted early，保守设计保证不溢出）、空标志可能延迟（empty deasserted late，不会读到假数据）。

## 关键要点

- **空满判断三种方法各有取舍**：MSB 圈数法面积最小且最常用；计数器法提供 Occupancy 信息但增加加法器开销；寄存器标志法适用于深度非 2 幂场景
- **Almost Full/Empty 用于提前背压**：在满/空前 N 个周期预警，使生产者/消费者有时间响应——广泛用于 AXI Stream 背压、DMA 预取等场景
- **非 2 幂深度增加设计复杂度**：指针回绕需显式比较逻辑（不能依赖自然溢出），空满判断需独立计数器——除非面积受限，建议向上调整到最近的 2 的幂
- **FWFT FIFO 降低读延迟到 0 周期**：数据从 SRAM 直接驱动到输出（组合输出），代价是输出时序路径变长——适合低延迟数据通路
- **异步 FIFO 的核心是格雷码同步**：格雷码确保相邻值仅 1 位翻转，即使同步器亚稳态也只导致"少计一圈"的保守结果——不会产生非法指针值
- **FIFO 是流水线吞吐匹配的核心工具**：生产者和消费者速率不匹配时，FIFO 提供弹性缓冲——深度选择取决于突发长度和速率比（Burst Length / Rate Ratio）
- **综合工具可推断 Block RAM**：当 DEPTH 和 WIDTH 超过阈值时，综合工具自动将 `logic [W-1:0] mem [0:D-1]` 映射为 Block RAM 宏单元——使用 `(* ram_style = "block" *)` 属性显式控制

## 与其他概念的关系

- [[rtl-design/concepts/Verilog-HDL|Verilog HDL]] — 同步 FIFO 的可综合 Verilog 实现，参数化设计方法，always_ff 模板和阻塞/非阻塞赋值规则
- [[rtl-design/concepts/跨时钟域设计|跨时钟域设计（CDC）]] — 异步 FIFO 中的格雷码指针同步、2-FF 同步器和亚稳态处理
- [[rtl-design/concepts/SystemVerilog|SystemVerilog]] — SV 的 interface、parameter、enum 等特性简化了复杂 FIFO 控制器的设计和验证
- [[rtl-design/concepts/流水线设计|流水线设计（Pipelining）]] — FIFO 是流水线级间缓冲的标准实现方式，FWFT 模式实现了零周期穿透延迟
