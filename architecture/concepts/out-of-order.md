---
type: concept
aliases:
  - 乱序执行
  - OoO
  - 动态调度
  - Dynamic Scheduling
tags:
  - asic
  - architecture
  - processor
  - out-of-order
  - microarchitecture
source_spec: "Hennessy & Patterson, Computer Architecture: A Quantitative Approach, 6th Ed; Tomasulo, 'An Efficient Algorithm for Exploiting Multiple Arithmetic Units', IBM Journal, 1967"
---

# 乱序执行（Out-of-Order Execution）

乱序执行是现代高性能处理器实现指令级并行（Instruction-Level Parallelism, ILP）的核心技术。与顺序流水线不同，乱序执行允许指令在不违反程序语义的前提下，以与程序顺序不同的次序执行——指令一旦操作数就绪即可发射执行，不再受前面独立指令阻塞的影响。

## 原理

### Tomasulo 算法与保留站

Tomasulo 算法是乱序执行的基础框架，最早在 IBM System/360 Model 91 中实现。其核心机制包括：保留站（Reservation Station, RS）作为功能单元的指令缓冲队列，每条指令在发射（Issue）时被分配到对应功能单元的保留站条目中，而不是按照程序顺序串行执行。源操作数通过标签（Tag）传递——当操作数尚未计算完成时，保留站中记录的是产生该操作数的保留站编号（而非寄存器号），一旦结果广播到公共数据总线（Common Data Bus, CDB），所有等待该结果的保留站同时捕获数据。这种寄存器重命名（Register Renaming）的早期形式消除了 WAR 和 WAW 伪冒险，使得更多的指令可以并行执行。

### 寄存器重命名与重排序缓冲区

现代乱序执行处理器将 Tomasulo 算法中的重命名机制系统化为重命名寄存器文件（Register Alias Table, RAT）。在指令译码阶段（重命名阶段），每条目的寄存器被分配一个空闲的物理寄存器，RAT 维护架构寄存器到物理寄存器的映射关系。WAR 和 WAW 冒险被彻底消除——每一条写操作都写入独立的物理寄存器。重排序缓冲区（Reorder Buffer, ROB）按程序顺序记录所有飞行中（In-Flight）的指令，每条指令在提交（Commit / Retirement）阶段从 ROB 头部按序退出，将物理寄存器的结果提交到架构状态（Architectural State）。ROB 支持精确异常（Precise Exception）——异常发生时，ROB 中异常指令之后的指令可以简单地被清空，程序状态回退到异常指令之前。

### 发射队列与唤醒-选择循环

指令完成重命名和分配后进入发射队列（Issue Queue / Scheduler）。发射队列的每个条目监控其源操作数的就绪状态——当所有源操作数就绪时，指令进入就绪（Ready）状态。每个时钟周期，发射队列执行唤醒（Wakeup）和选择（Select）两个操作：唤醒阶段根据 CDB 上广播的结果标签更新所有条目中匹配的源操作数状态；选择阶段从所有就绪指令中按照某种策略（如年龄优先 / 最快就绪优先）选出若干条指令发射到功能单元执行。唤醒-选择循环（Wakeup-Select Loop）是乱序处理器中最关键的时序路径，直接影响处理器频率。

### 访存排序与存储队列

Load-Store Queue（LSQ）负责维护访存指令的顺序语义。Load 指令在发出前必须检查 Store Queue 中是否有地址冲突的前序 Store：如果 Store 地址已确定且与 Load 地址一致，Load 可以直接从 Store Queue 转发数据（Store-to-Load Forwarding）；如果 Store 地址未确定，Load 必须等待地址确定（Memory Disambiguation）。Store 指令在提交阶段才写入数据缓存（Write-Through 或 Write-Back），确保了存储操作的不可逆性——错误的 Store 指令在被提交前不会污染内存系统。

## 关键要点

- Tomasulo 算法的核心创新是用标签传递代替了寄存器号的静态绑定，使 WAR 和 WAW 冒险在硬件层面完全消除
- RAT（Register Alias Table）每次重命名时创建新的映射条目，提交时释放旧的物理寄存器——寄存器的分配-释放生命周期由分支指令的检查点（Checkpoint）管理
- ROB 的大小决定了飞行中指令的数量上限（Window Size），典型值为 200-300+ 条指令
- 唤醒-选择循环是关键路径：唤醒需要比较所有发射队列条目与 CDB 标签的 CAM（Content-Addressable Memory）匹配，选择需要从就绪条目中按优先级挑选
- Store-to-Load Forwarding 处理 RAW 冒险的关键是确保 Load 总是读取到最近的、地址相同的前序 Store 的数据
- 存储指令在 ROB 提交之前不能写入 L1 数据缓存——否则发生异常时无法回退
- 分支误预测的恢复涉及 RAT 回滚（Branch Checkpoint）和 ROB 清空——检查点记录了分支指令时刻的 RAT 映射快照
- 物理寄存器文件（Physical Register File, PRF）的端口数限制（读写端口）成为乱序执行宽度（Issue Width）的瓶颈

## 与其他概念的关系

- [[architecture/concepts/pipelining|流水线（Pipelining）]] — 乱序执行是顺序流水线架构的自然演化，解决了顺序流水线中独立指令互相阻塞的问题
- [[architecture/concepts/branch-prediction|分支预测（Branch Prediction）]] — 分支预测为乱序执行提供正确的指令流供应，预测精度直接影响 ROB 中有效指令的比例
- [[architecture/concepts/memory-hierarchy|存储层次（Memory Hierarchy）]] — Load/Store 指令的延迟在乱序执行中被部分掩盖（Memory-Level Parallelism），但缓存未命中仍然是性能限制的主要瓶颈
- [[architecture/concepts/cache-coherence|缓存一致性（Cache Coherence）]] — 多核乱序执行下的内存排序需要一致性协议保证正确的共享数据语义
