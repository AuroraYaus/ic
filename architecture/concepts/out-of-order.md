---
type: concept
aliases:
  - 乱序执行
  - OoO
  - 动态调度
  - Dynamic Scheduling
  - Tomasulo算法
tags:
  - asic
  - architecture
  - processor
  - out-of-order
  - microarchitecture
  - ilp
source_spec: "Hennessy & Patterson, Computer Architecture: A Quantitative Approach, 6th Ed; Tomasulo, 'An Efficient Algorithm for Exploiting Multiple Arithmetic Units', IBM Journal, 1967; Smith & Sohi, 'The Microarchitecture of Superscalar Processors', Proc. IEEE, 1995"
---

# 乱序执行（Out-of-Order Execution）

乱序执行是现代高性能处理器实现指令级并行的核心技术。与顺序流水线不同，乱序执行允许指令在不违反程序语义的前提下以与程序顺序不同的次序执行——指令一旦操作数就绪即可发射执行，不再受前面无关指令阻塞的影响。这一机制将处理器的有效执行窗口从顺序流水线的几级扩展到数百条指令，大幅提升后端功能单元利用率。

## 原理

### Tomasulo 算法与保留站

Tomasulo 算法是乱序执行的基础框架，最早在 IBM System/360 Model 91 中实现。其核心机制：保留站作为功能单元的指令缓冲队列，每条指令在发射时被分配到对应功能单元的保留站条目中。源操作数通过标签传递——当操作数尚未计算完成时，保留站中记录的是产生该操作数的保留站编号而非寄存器号，一旦结果广播到公共数据总线（Common Data Bus, CDB），所有等待该结果的保留站同时捕获数据。这种寄存器重命名早期形式消除了 WAR 和 WAW 伪冒险。

### 寄存器重命名与重排序缓冲区

现代乱序执行处理器将 Tomasulo 的重命名机制系统化为物理寄存器文件和重命名寄存器映射表（Register Alias Table, RAT）。在译码后的重命名阶段，每条目的寄存器被分配一个空闲的物理寄存器（从 Free List 获取），RAT 维护架构寄存器到物理寄存器的映射关系。读端口通过 RAT 获取操作数对应的最新物理寄存器号，写端口通过分配新的物理寄存器消除 WAR/WAW——每条写操作写入独立物理寄存器，后续读取总是看到正确的最新值。

重排序缓冲区（Reorder Buffer, ROB）按程序顺序记录所有飞行中的指令信息：指令类型（ALU/Load/Store/Branch）、目标架构寄存器号、结果值和完成状态（Done Bit）。ROB 的提交阶段从其头部按序弹出指令：如果指令已完成则写回结果并弹出；如果未完成则流水线在 ROB 头部阻塞。ROB 支持精确异常：异常发生时只需标记 ROB 中对应条目的异常状态，提交时在异常指令处停止，其后的 ROB 条目全部清空——程序状态精确回退到异常指令执行之前。

### 发射队列与唤醒-选择循环

指令完成重命名和分配后进入发射队列。每个条目持续监控源操作数的就绪状态——每个源操作数对应一个 Ready 位。每个时钟周期执行：唤醒阶段——扫描所有条目，将 CDB 上广播的结果标签与条目源操作数标签通过 CAM 比较，匹配时标记操作数为就绪；选择阶段——从所有操作数就绪的指令中选取若干条发射到功能单元，通常按最老优先策略。唤醒-选择是乱序处理器中最关键的时序路径，随着发射队列增大 CAM 比较器网络开销平方增长，实际设计中使用分簇或分布式调度来管理时序。

### 访存排序与存储队列

Load-Store Queue（LSQ）负责维护访存指令的顺序语义。Load 指令在发出前必须检查 LSQ 中所有前序 Store 指令：如果存在地址匹配的前序 Store 且数据已就绪，则通过 Store-to-Load Forwarding 直接从 LSQ 获取数据；如果存在地址未确定的前序 Store，Load 必须等待地址确定（Memory Disambiguation）。Store 指令在提交阶段才真正写入 L1 D-Cache——保证了 Store 操作的不可逆性，错误路径上的 Store 不会污染内存系统。

### 分支误预测恢复

分支误预测恢复是乱序执行中最昂贵的操作。当分支指令在 EX 阶段确定实际方向与预测不一致时，处理器需要：刷新 ROB 中该分支之后的所有指令；将 RAT 恢复到分支时刻的映射状态（通过分支检查点快照机制）；回收被错误指令占用的物理寄存器；清空发射队列中错误路径的指令。恢复的时钟周期开销（通常 10-30 周期）直接构成有效误预测惩罚。

### 物理寄存器文件设计

物理寄存器文件（Physical Register File, PRF）是乱序执行的数据中枢。PRF 的端口数（读写端口数量）决定了每周期可以发射和提交的最大指令数：对于 W 宽度的发射，至少需要 2W 个读端口（每条指令最多两个源操作数）；对于 C 宽度的提交，至少需要 C 个写端口（每条提交的指令将一个结果写入 PRF）。总端口数 = 2W + C。

多端口 SRAM 的面积和功耗随端口数平方增长。实际设计中使用分簇策略：将 PRF 划分为多个物理体，每个体有独立的读写端口；或使用寄存器文件复制（Replication），每个功能单元簇拥有 PRF 的独立副本，通过广播机制维护跨副本的一致性。后一种方案在 Intel Core 的 Clustered Microarchitecture 中被采用——两个核心簇各自拥有独立的 PRF 和发射队列，通过簇间通信总线交换数据。

### 内存依赖预测与投机 Load

Load 指令在乱序执行中面临与 Store 指令的依赖不确定性。前序 Store 的地址尚未确定时，Load 无法确定是否可以安全地执行（是否与某条前序 Store 存在地址冲突）。内存依赖预测器（Memory Dependence Predictor）学习 Load-Store 对的冲突历史：如果历史上某 Load 和某 Store 频繁冲突，预测器标记该 Load 为 Speculative——允许 Load 投机执行但将其结果标记为投机性；当冲突的 Store 地址确定后，验证 Load 的正确性。如果 Load 投机正确，无额外开销；如果错误，Load 及其后续依赖指令需要从该点重放（Replay）。重放机制对性能的影响显著——高冲突率的 Load 频繁触发重放导致性能退化。

### 乱序执行的实际限制

虽然乱序执行理论上可以提取无限的 ILP（只要指令窗口足够大），实际性能受多种因素限制。指令窗口（ROB + 发射队列）的大小是核心约束——更大的窗口可以覆盖更多的独立指令，但窗口增大的代价是面积和功耗的平方到立方增长（CAM 比较器、物理寄存器文件端口等）。实际设计中窗口大小在 200-500 指令之间——这是面积、功耗和性能的三维帕累托最优前沿。

另一种限制是分支误预测——每次误预测清空窗口中的所有投机指令，相当于窗口的有效利用率下降。如果误预测率为 3% 且分支频率为 20%，平均每执行 100 条指令就产生约 3 × 0.2 = 0.6 次误预测。如果每次误预测清空平均 100 条指令，那么约 60% 的指令是"无效投机"——虽然硬件在执行它们，但结果永远不会被提交。这揭示了分支预测对乱序执行性能的决定性作用：提高预测精度不仅是减少暂停，更是增加前端向后端输送有效指令的效率。

## 关键要点

- Tomasulo 算法的核心创新是用标签传递代替寄存器号静态绑定，使 WAR 和 WAW 在硬件层面完全消除
- RAT 每次重命名时创建新的架构到物理的映射，每次提交时释放老的物理寄存器，由 Free List 管理分配-释放生命周期
- ROB 大小决定了飞行中指令数量上限（Window Size），典型值 200-300+ 条（Apple M1 约 630 条，Intel Golden Cove 512 条）
- 唤醒-选择循环是关键路径：CAM 匹配 N 个发射队列条目乘以 M 个 CDB 广播标签，规模和功耗显著增长
- Store-to-Load Forwarding 是 RAW 的关键解决路径：Load 必须从最近的前序 Store 获取数据，地址匹配优先于数据匹配
- Store 在 ROB 提交之前不能写入 L1 D-Cache——ROB 提交是存储可见性的关卡
- 分支误预测恢复涉及 RAT 回滚：带检查点维护最多 N 个分支时刻的快照（64-128 条），超过容量时较新分支暂停发射
- 物理寄存器文件端口数限制是乱序执行宽度的瓶颈：N-wide 提交需要 N 个写端口，M-wide 发射至少需要 2M 个读端口
- 获取更宽 ILP 的代价是面积和功耗的平方到立方增长——发射队列越大 CAM 功耗越高

## 与其他概念的关系

- [[architecture/concepts/pipelining|流水线（Pipelining）]] — 乱序执行是顺序流水线的进化版本，通过动态调度消除独立指令间阻塞，是 ILP 利用的高级阶段
- [[architecture/concepts/branch-prediction|分支预测（Branch Prediction）]] — 分支预测为乱序执行提供持续的投机指令流，预测精度直接决定 ROB 中有效工作量的比例
- [[architecture/concepts/memory-hierarchy|存储层次（Memory Hierarchy）]] — 缓存未命中延迟通过 MLP 被部分掩盖，但缓存缺失仍是首要性能限制因素
- [[architecture/concepts/cache-coherence|缓存一致性（Cache Coherence）]] — 多核乱序执行中，各核心的 Load/Store 提交顺序必须与内存一致性模型匹配
