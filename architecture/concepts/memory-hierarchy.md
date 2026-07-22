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
source_spec: "Hennessy & Patterson, Computer Architecture: A Quantitative Approach, 6th Ed; Jacob, Ng & Wang, Memory Systems: Cache, DRAM, Disk; Intel Optimization Reference Manual"
---

# 存储层次（Memory Hierarchy）

存储层次是现代计算机体系结构的基石，利用程序访问的局部性原理（Locality Principle）——时间局部性（Temporal Locality：最近访问的数据很可能再次被访问）和空间局部性（Spatial Locality：邻近地址的数据很可能很快被访问）——通过多级不同容量和延迟的存储介质，构建从寄存器（0 周期）到 L1（2-4 周期）、L2（10-15 周期）、L3/LLC（30-50 周期）、主存 DRAM（200-400 周期）、持久存储（数百万周期）的金字塔结构。

## 原理

### 缓存组织方式

缓存的行列映射方式决定冲突缺失率：直接映射（Direct-Mapped）每个地址只有一个槽位，简单但冲突最多；全相联（Fully-Associative）任意地址可放入任意槽位，零冲突但需 CAM 并行搜索所有槽位，面积和功耗随容量平方增长；组相联（Set-Associative）是实用折中——N 路组相联将缓存分为若干组（Set），组内 N 个槽位，地址的 Index 位选组，Tag 在组内 N 路中并行比较检测命中。典型 L1 数据缓存为 4-8 路组相联，L2 为 8-16 路。

### 替换策略

当缓存满需加载新行时选择牺牲者（Victim）：LRU（Least Recently Used）选择最久未访问的行——理论近似最优但需维护每组的全序，关联度高时实现昂贵；伪 LRU（Tree-based Pseudo-LRU）用二叉树逼近 LRU，每节点 1 bit 记录子树访问先后，硬件成本 $O(\log_2 N)$；RRIP（Re-Reference Interval Prediction）为每行分配再引用预测值（RRPV），新插入行赋较高 RRPV（表示近期不再使用），命中时清零，替换时选最高 RRPV 者——对扫描型（Scan）访存模式的抵抗性远优于 LRU；BIP（Bimodal Insertion Policy）以一定概率将新行插入 LRU 位置而非 MRU，有效抑制混叠（Thrashing）场景下工作集大于关联度时的性能骤降。

### 写策略与地址映射

写策略：写直达（Write-Through）每次写同步更新下级存储——实现简单但写带宽压力大；写回（Write-Back）仅在替换时写回，依赖脏位（Dirty Bit）标记——主流选择。配合写分配（Write-Allocate，先加载再写入缓存）vs 非写分配（No-Write-Allocate，绕过缓存直接写下级）形成四种组合，现代处理器惯用写回 + 写分配。

地址映射：PIPT（Physically Indexed, Physically Tagged）使用物理地址索引和标签——慢但无别名问题，L2/L3 常用；VIPT（Virtually Indexed, Physically Tagged）用 VA 低位（与 PA 相同的页内偏移部分）索引、PA 标签比较，实现 TLB 查找与缓存索引并行——但受 Size $\leq$ Ways $\times$ PageSize 约束（如 16 路 $\times$ 4KB = 64KB 为上限），否则产生别名（Aliasing）。

### TLB 与预取

TLB（Translation Lookaside Buffer）缓存页表项（VPN$\to$PFN），现代多级 TLB 结构：微 TLB（L1，32-64 项，全相联，1 周期）覆盖最近访问页，主 TLB（L2，512-4096 项，4-8 路组相联）处理 L1 缺失。TLB 缺失触发硬件页表遍历器（x86/ARM）或软件 TLB 重填（MIPS）。

预取（Prefetching）掩盖访存延迟：下一行预取（Next-Line）最简单——命中后自动加载下一缓存行；步长预取（Stride）检测固定步长模式（如二维数组列遍历）；Markov 预取用历史访问序列建立转移概率模型；基于签名的预取（Signature-Based）以 PC + 历史访问模式哈希为特征索引预测表。

## 关键要点

- AMAT（Average Memory Access Time）= Hit Time + Miss Rate $\times$ Miss Penalty，三大缺失类型（3C）：强制缺失（Compulsory，首次访问）、容量缺失（Capacity，工作集超缓存容量）、冲突缺失（Conflict，多地址映射至同一组）
- VIPT 容量上限由页面大小和路数决定：Size $\leq$ Ways $\times$ PageSize；L1 I-Cache/D-Cache 通常为 VIPT，L2/L3 为 PIPT
- 写回 + 写分配是现代处理器主流组合：写命中只更新缓存（设脏位），写缺失先加载分配再写入
- RRIP + BIP 组合在扫描密集和混叠场景下性能显著优于 LRU，Intel 自 Sandy Bridge 起采用
- TLB 覆盖（TLB Reach）= TLB 项数 $\times$ 页面大小；大页（2MB/1GB）将 TLB 覆盖提升数百至数千倍，数据库和虚拟化场景收益巨大
- TLB Shootdown：多核修改页表后需 IPI 通知所有核心使对应 TLB 项无效（INVLPG），核心数多时延迟可达微秒级
- 缓存行大小从 32B/64B（主流）到 128B（Apple M 系列）——更大行利用空间局部性但增加伪共享（False Sharing）和带宽浪费
- 现代 SoC 系统级缓存（SLC/L3）服务多个主设备，需按流量类型区分策略（CPU 可缓存 vs 多媒体流旁路）

## 与其他概念的关系

- [[architecture/concepts/cache-coherence|缓存一致性（Cache Coherence）]] — 多核私有 L1/L2 缓存需一致性协议维护共享内存视图，MSI/MESI/MOESI 等协议依赖缓存行状态机
- [[architecture/concepts/out-of-order|乱序执行（Out-of-Order Execution）]] — 乱序处理器利用 MLP（Memory-Level Parallelism）通过多条并行飞行中的未命中请求掩盖缓存延迟
- [[architecture/concepts/on-chip-bus|片上总线（On-Chip Bus）]] — AXI 的未完成事务数（Outstanding）和乱序返回能力直接限制 MLP 的有效发挥
- [[concepts/cmos-fundamentals|CMOS 基础]] — 6T SRAM 单元是缓存基础单元，其读稳定性（Read Static Noise Margin）随工艺缩小退化
