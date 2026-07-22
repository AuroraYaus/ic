---
type: concept
aliases:
  - 流水线
  - Pipeline
  - 指令流水线
tags:
  - asic
  - architecture
  - processor
  - pipelining
  - microarchitecture
source_spec: "Hennessy & Patterson, Computer Architecture: A Quantitative Approach, 6th Ed; Patterson & Hennessy, Computer Organization and Design, RISC-V Ed"
---

# 流水线（Pipelining）

流水线是处理器微架构中最核心的性能提升技术之一。它将一条指令的执行过程划分为多个阶段（Stage），每个时钟周期可以同时处理不同指令的不同阶段，从而在不提高时钟频率的前提下，将指令吞吐率（Throughput）从单周期每 N 个周期完成一条指令提升到每个周期完成一条指令的理想情况。

## 原理

### 经典 RISC 五级流水线

经典 RISC 五级流水线将指令执行划分为五个阶段：取指（Instruction Fetch, IF）、译码（Instruction Decode, ID）、执行（Execute, EX）、访存（Memory Access, MEM）和写回（Write Back, WB）。每一个阶段由一组流水线寄存器（Pipeline Register）隔开，寄存器在时钟边沿捕获上一阶段的输出作为本阶段的输入。在理想情况下，第 N 个时钟周期时，IF 处理指令 i+4，ID 处理指令 i+3，EX 处理指令 i+2，MEM 处理指令 i+1，WB 处理指令 i。CPI（Cycles Per Instruction）趋近于 1。

### 数据冒险与转发

流水线中指令之间存在数据依赖时会发生数据冒险（Data Hazard）。RAW（Read After Write）是最常见的数据冒险类型：后续指令需要读取前面指令尚未写回的结果。WAR（Write After Read）和 WAW（Write After Write）在乱序执行处理器中才会出现。转发（Forwarding/Bypassing）通过在 EX 阶段直接从流水线寄存器或执行结果中旁路数据到依赖指令的输入，避免了等待 WB 阶段完成再读取寄存器文件的延迟。转发路径由冒险检测单元（Hazard Detection Unit）根据源寄存器和目标寄存器的比较结果生成控制信号。当转发无法解决时（如 Load 指令后的立即使用，即 Load-Use Hazard），流水线必须插入一个流水线气泡（Bubble / Stall）。

### 控制冒险与分支处理

控制冒险（Control Hazard）由分支指令和跳转指令引起。当处理器遇到条件分支时，下一条指令的地址取决于分支结果，而分支结果在 EX 阶段才能确定——这意味着如果按顺序取指，将浪费 IF 和 ID 两个阶段的指令。常见解决方案包括：流水线冲刷（Flush/Fluish）——在分支确定后 Kill 掉流水线中误取的指令；延迟分支（Delayed Branch）——编译器将独立指令填入分支延迟槽；分支预测（Branch Prediction）——在取指阶段预测分支方向。现代处理器普遍采用分支预测 + 误预测恢复（Misprediction Recovery）的方案。

### 结构冒险

结构冒险（Structural Hazard）指两条以上指令在同一时钟周期竞争同一硬件资源（如单端口存储器同时服务于 IF 阶段的取指和 MEM 阶段的访存）。解决方案包括：分离指令缓存和数据缓存（Harvard Architecture 的缓存层面实现）、增加资源副本（多端口寄存器文件）、以及时分复用调度。

## 关键要点

- 流水线的加速比理论上限为流水线级数 N（N 级流水线理想加速比为 N），实际受流水线寄存器开销、冒险处理损失和不平衡的阶段划分限制
- RAW 冒险在五级流水线中有三条转发路径：EX/MEM → EX、MEM/WB → EX，以及 Load 的 MEM/WB → EX 特殊路径
- 冒险检测单元（Hazard Detection Unit）比较相邻指令的源寄存器（Rs1/Rs2）与目标寄存器（Rd），生成 PC 冻结（PCWrite）和流水线寄存器冻结（IF/IDWrite）信号
- 流水线气泡（Bubble）通过插入 NOP 实现：控制信号清零，不写入寄存器文件，不改变 PC
- Load-Use Hazard 需要插入一个周期的 stall：将 ID/EX 寄存器的控制信号清零（变成 NOP），同时冻结 PC 和 IF/ID 寄存器
- 分支指令的误预测惩罚（Misprediction Penalty）在五级流水线中为 2 个周期（IF 和 ID 的指令作废），在深流水线中可达 15-20 周期
- 流水线深度受限于阶段划分的平衡性：某一阶段的关键路径过长会使该阶段成为瓶颈，限制时钟频率提升
- 超标量（Superscalar）在流水线基础上增加并行发射宽度（每周期发射多条指令），进一步利用指令级并行（ILP）
- 与 RTL 级流水线（模块间插寄存器切断关键路径）不同，微架构级流水线涉及指令间的数据依赖管理和精确异常（Precise Exception）维护

## 与其他概念的关系

- [[architecture/concepts/out-of-order|乱序执行（Out-of-Order Execution）]] — 乱序执行在流水线基础上通过动态调度进一步提升 ILP，其 Tomasulo 算法本质上是对流水线中 RAW 冒险的动态管理
- [[architecture/concepts/branch-prediction|分支预测（Branch Prediction）]] — 分支预测是流水线控制冒险的高级解决方案，预测精度直接影响流水线效率
- [[concepts/cmos-fundamentals|CMOS 基础]] — 时钟频率和流水线级数的物理极限由 CMOS 工艺的晶体管开关速度和连线延迟决定
- [[rtl-design/concepts/verilog-hdl|Verilog HDL 入门]] — RTL 编码中 always_ff 块描述的寄存器行为直接对应流水线寄存器的硬件实现
