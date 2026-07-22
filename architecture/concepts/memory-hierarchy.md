---
type: concept
aliases:
  - 存储层次
  - Memory Hierarchy
  - 缓存层次
  - Cache Hierarchy
tags:
  - asic
  - architecture
  - memory
  - cache
source_spec: "Hennessy & Patterson, Computer Architecture: A Quantitative Approach, 6th Ed; Jacob, Ng & Wang, Memory Systems: Cache, DRAM, Disk; Denning, 'The Working Set Model for Program Behavior', CACM 1968"
---

# 存储层次（Memory Hierarchy）

存储层次是计算机体系结构中最基本的设计原则之一，其核心思想是利用程序访问的局部性原理，通过多级不同容量、不同速度的存储设备构建金字塔结构——从容量小、速度快、离处理器最近的寄存器堆到容量大、速度慢、离处理器最远的磁盘/SSD。每一级存储作为上一级的缓存，以接近上一级的速度提供接近下一级的容量，将平均访问时间（Average Memory Access Time, AMAT）最小化。

## 原理

### 局部性原理

局部性原理（Principle of Locality）是存储层次得以成立的理论基础，分为时间局部性（Temporal Locality）和空间局部性（Spatial Locality）。时间局部性指一个内存地址被访问后，短期内很可能再次被访问——这是缓存工作的基础，最近访问的数据和指令保留在较快存储中。空间局部性指一个内存地址被访问后，其邻近地址很可能很快被访问——这是缓存行（Cache Line / Block）粒度取数的依据，每次缓存缺失时从下一级取出整整一个块（通常 64 字节），提前将可能需要的邻近数据带上。指令流天然具有强空间局部性（顺序执行），数据流中的数组遍历、结构体字段访问也遵循空间局部性。Denning 的工作集模型（Working Set Model）将程序访存行为形式化为时间窗口内的地址集合——只要工作集能放入缓存就不会发生容量缺失。

### 缓存组织方式

缓存的组织方式由三个参数定义：缓存总容量（C）、块大小（B）、组相联度（Associativity, N）。三种组织方式：直接映射（Direct-Mapped, N=1）——每个内存地址仅能放入缓存中的唯一定位，硬件最简单但冲突缺失（Conflict Miss）率最高；全相联（Fully-Associative）——任何地址可放入任何位置，缺失率最低但硬件最复杂，需 CAM 搜索或全并行 Tag 比较，仅适用于小容量结构（如 TLB）；组相联（Set-Associative, N-way）——每个地址可放入 N 路中的任一路，由 Index 选组后组内选路，是实际处理器的主流方案。L1 数据缓存通常 4-8 路，L2 为 8-16 路，L3 为 16-20 路。缓存索引位宽 = log2(C / B / N)，Tag 位宽 = 物理地址宽度 - Index 位宽 - 页内偏移位宽。

### 替换策略

当缓存缺失且目标组所有路都被占用时，替换策略（Replacement Policy）决定淘汰哪个缓存行。LRU（Least Recently Used）跟踪每路的访问时间戳，淘汰最久未访行——理论最优但硬件开销 O(N log N) 位。伪 LRU（Pseudo-LRU / Tree-PLRU）用二叉树近似：每次访问沿路径标记，替换时沿未标记方向找——N 路仅需 N-1 位，精度下降约 5-10%。RRIP（Re-Reference Interval Prediction）是现代处理器的实际主流策略：每行分配一个 RRPV 值，新插入时根据策略预设（Near-immediate 或 Long），每次命中清零，替换选 RRPV 最高者。RRIP 对扫描模式抵抗力显著优于 LRU——LRU 遇扫描流会将整个组刷成新数据而淘汰所有有用行；RRIP 给扫描数据分配高 RRPV，一旦扫描结束这些行立刻成为候选淘汰对象。SHiP（Signature-based Hit Prediction）通过访存 PC 的签名历史预测插入策略。

### 写策略

写策略决定处理器写操作如何传播到缓存和下级存储。写直达（Write-Through）——Store 同时写缓存和下级存储，保证缓存与下级一致，实现简单但产生大量写流量。写回（Write-Back）——Store 仅写缓存并标记为脏，被替换时才写回下级，显著减少写流量。写分配（Write-Allocate）——Store 缺失时先将缺失行读入缓存再写入，与写回配对；非写分配（No-Write-Allocate）——Store 缺失时绕过缓存直接写下级，与写直达配对。写回 + 写分配是现代 L1/L2/L3 的标准组合；考虑到写缓冲（Write Buffer / Store Buffer）的合并效应（Write Combining），多个连续 Store 可合并为单次缓存行粒度的写回。

### VIPT 与 PIPT 缓存

L1 缓存面临 TLB 访问延迟与缓存访问时间的关键权衡。PIPT（Physically Indexed, Physically Tagged）——Index 和 Tag 都来自物理地址，需先等 TLB 转换才能开始缓存访问，延迟大但无歧义。VIPT（Virtually Indexed, Physically Tagged）——Index 使用虚拟地址低位（页内偏移与物理地址一致），Tag 等待 TLB 转换后的物理地址进行并行比较，是 L1 缓存的标准实现。VIPT 的约束：缓存容量 / 相联度不能超过页大小（4KB）。对于 32KB 8 路缓存，Index = 12 位（恰占满页偏移），满足约束；64KB 需至少 16 路或改用 PIPT。VIVT 虽避免 TLB 访问但引入同义词/反义词（Synonym/Alias）问题，现代处理器基本不用。

### TLB 与虚拟内存

转译后备缓冲器（Translation Lookaside Buffer, TLB）是虚拟地址到物理地址转换的专用缓存。每条 TLB 条目存储 VPN→PPN 映射及权限位（R/W/X）、脏位（Dirty）、访问位（Accessed）。现代处理器有两级 TLB：L1 ITLB/DTLB 各约 32-64 条目，L2 统一 TLB 约 512-2048 条目。TLB 缺失需要硬件页表遍历（Page Table Walk, PTW），4 级 4KB 页表最坏需 4 次内存访问获取物理地址。大页（2MB/1GB Huge Page）显著减少 TLB 缺失；TLB Shootdown 在多核系统中一个核心修改页表时需向其他核心发 IPI 无效化其 TLB。

### 硬件预取

硬件预取器监测访存模式，在程序显式请求前主动将数据加载到缓存中掩盖内存延迟。顺序预取器（Next-Line）对顺序访问有效但浪费带宽于随机访问。步幅预取器（Stride Prefetcher）跟踪每个 PC 的连续两次缺失地址差（步幅）。更高级的方案包括 GHB（Global History Buffer）、SMS（Spatial Memory Streaming）、BOP（Best Offset Prefetching）。预取的三个关键控制参数：预取距离（提前多少步）、预取度（每次触发预取几条行）、预取节流（防止过激预取污染缓存）。现代预取器采用"预取共享"模式以避免不必要地拉取 Exclusive 状态触发的无效化广播。

## 关键要点

- AMAT = hit_time + miss_rate * miss_penalty，三级缓存需逐级累加
- 三种缺失类型：强制性（Cold，首次）、容量性（Capacity，工作集超容）、冲突性（Conflict，相联度不足）
- LRU 最大软肋是扫描/流模式——一次扫描淘汰全部有用数据；RRIP 方案已广泛取代纯 LRU
- VIPT 缓存尺寸上限 = N_way * page_size，突破需 PIPT 或 Way-Prediction 技术
- TLB 覆盖范围 = 条目数 * 页大小；2MB 大页使覆盖范围扩大 512 倍
- 存储层次每级本质上是"容量-延迟-带宽-功耗"四维权衡，不存在单一最优解
- 预取器的预取距离、预取度和节流三参数共同决定效率，过度预取可通过污染导致性能下降
- CXL 扩展内存（Type-3 Memory）在 DRAM 和存储间插入新的层次，提供近 DRAM 带宽但延迟高一个数量级

## 与其他概念的关系

- [[architecture/concepts/cache-coherence|缓存一致性（Cache Coherence）]] — 私有缓存的 MESI 状态转换与写策略、替换策略深度耦合，一致性消息延迟由缓存层次决定
- [[architecture/concepts/out-of-order|乱序执行（Out-of-Order Execution）]] — 乱序执行的 MLP（Memory-Level Parallelism）通过同时容忍多个缓存缺失来掩盖深存储层次的延迟
- [[architecture/concepts/on-chip-bus|片上总线（On-Chip Bus）]] — 缓存缺失和写回事务通过 AXI/CHI 在各级存储间传输，总线延迟直接贡献 miss_penalty
- [[asic-flow/concepts/static-timing-analysis|静态时序分析（STA）]] — SRAM 缓存阵列的读写时序含 Tag 比较、Data MUX、Way Select 等关键路径
