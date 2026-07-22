---
type: concept
aliases:
  - SoC 架构
  - 片上系统架构
  - SoC Architecture
  - System-on-Chip Architecture
tags:
  - asic
  - architecture
  - soc
source_spec: "ARM AMBA Specifications; UCIe Specification Rev 1.1; IEEE Hot Chips Conference Proceedings; ARM TrustZone Technology Overview; Keating et al., Low Power Methodology Manual"
---

# SoC 架构（SoC Architecture）

片上系统（System-on-Chip, SoC）将过去分布于 PCB 板的多个独立芯片集成到单一硅片。现代 SoC 是典型的异构多核系统，包含多种性能等级的处理器、多级缓存与互连、外设控制器、以及 Die-to-Die 集成物理层。

## 原理

### 异构多核集成

现代 SoC 的异构核分工：Cortex-A/X 系列（应用处理器，宽发射、深流水、大乱序窗口——追求单线程峰值性能）；Cortex-R 系列（实时处理器，确定性延迟——用于基带、汽车安全、存储控制器）；Cortex-M 系列（低功耗微控制器——用于传感器融合和 always-on 域）。协同处理器包括：GPU（大规模并行图形与 GPGPU 计算）、NPU/TPU（张量运算，推理能效比 GPU 高 5-10 倍）、DSP（音频/视觉/基带信号处理，VLIW + SIMD 架构）、ISP（图像信号处理管道——去马赛克、白平衡、降噪、HDR 融合）。异构调度的关键是操作系统感知不同核心的能力差异（ARM DynamIQ 共享簇内大小核，Intel Thread Director 硬件辅助调度）。

### 互连架构选择

互连选择取决于规模与带宽需求：交叉开关（Crossbar）适用于 <10 主设备——全连接、非阻塞、最低延迟，但面积 $O(N \times M)$；共享总线（Shared Bus）适用于低带宽外设——简单但全系统共享带宽，单主占用时其余主设备等待；NoC（Network-on-Chip）适用于 >30 IP 的大规模 SoC——通过分组交换和分布式路由将聚合带宽扩展到 TB/s 量级。多层总线架构为中型 SoC（10-30 主设备）的常用折中：高性能主设备通过 AXI 高速层通信，低速外设级联至 APB 子网。

### 存储墙与系统缓存

"存储墙"（Memory Wall）是 SoC 设计核心瓶颈：处理器性能指数增长，但 DRAM 延迟仅以每年约 7% 改善，带宽增长受引脚数和封装限制。缓解手段：更宽的存储器接口（DDR5/LPDDR5 64-bit 通道、HBM 1024-bit 宽总线）、3D 堆叠存储器（HBM 将 DRAM 堆栈置于硅中介层上，带宽达 TB/s 级）、近存计算（Processing-in-Memory / Near-Memory Computing）、以及多级缓存 + 预取层次。系统级缓存（SLC/L3）位于互连与 DRAM 控制器之间，所有 IP 共享——CPU 局部性强适合大缓存行，GPU 带宽密集适合更细粒度的缓存策略，多媒体数据流（一次性使用）应配置为缓存旁路（Bypass）以避免缓存污染。

### I/O 一致性与 SMMU

非 CPU 的 I/O 主设备（GPU、PCIe RC、加速器）通过 IOMMU/SMMU 将设备虚拟地址（GVA/IOVA）转换为系统物理地址（SPA），提供地址转换和内存保护。SMMU 中的 ATS（Address Translation Service）和 ATC（Address Translation Cache）允许设备缓存地址转换结果并主动请求预转换——设备侧 TLB 大幅降低转换延迟。I/O 一致性通过 CHI/CXL 实现：设备作为 RN-I 节点发出 ReadShared 获得最新一致数据，或用 ReadNoSnp 绕过一致性流量降低带宽开销。

### 电源/时钟域与 Chiplet 设计

电源架构：每个 IP 可分配独立电源域进行细粒度电源门控（Power Gating）；DVFS 域允许独立电压/频点调节——always-on 域（AON）维持唤醒和安全管理。时钟域划分由 PLL 和各域分频器管理，跨域同步通过异步 FIFO 或握手同步器。

Die-to-Die 互连：UCIe（Universal Chiplet Interconnect Express）为开放行业标准，定义标准封装到先进封装（2D/2.5D/3D）的 PHY 和链路层，最高海岸线带宽密度 1.3 TB/s/mm。BoW/BoW+（Bunch-of-Wires）为开源并行 D2D 接口。AIB（Advanced Interface Bus）用于 Intel 生态系统。Chiplet 设计优势：良率提升（小芯片良率远高于单片大芯片）、IP 复用、工艺节点混合（计算芯片用 3nm，I/O 芯片用成熟节点）。挑战：D2D PHY 功耗、跨晶粒热管理、测试访问统一。

### 安全架构

TEE（Trusted Execution Environment）通过 ARM TrustZone（安全/非安全世界硬件隔离，NS 位标记总线事务）或 RISC-V PMP/ePMP 实现物理隔离。安全启动链（Secure Boot Chain）：ROM 代码验证初始固件签名（基于 eFuse 中烧录的根公钥哈希），逐级建立信任链至 OS/应用。硬件信任根（Hardware Root of Trust）提供安全存储（eFuse/OTP）、真随机数发生器（TRNG）和密码加速器。

## 关键要点

- 异构多核的调度策略（DynamIQ / Thread Director）决定工作负载分配效率——错误的核心选择导致能效浪费或性能不足
- NoC 总带宽需按最坏并发流量矩阵设计——实时 IP（显示器、音频）带宽必须保证，其余按统计复用
- SLC 每簇 2-8 MB，命中率低于 L2（20-40%），但每次命中消除一次 DRAM 往返（数百周期），价值极高
- IOMMU/SMMU 引入地址转换延迟——ATC/ATS 是设备侧 TLB 缓存，对高频 IO 至关重要
- DVFS 响应受限于电源域开关时间常数（数十至数百微秒），快速响应依赖硬件自主调节（Hardware Autonomous DVFS）
- Chiplet 代价不在性能（D2D 延迟 <2ns 先进封装），而在设计复杂性：协同验证、封装协同设计、跨晶粒一致性协议
- UCIe 支持 CXL 和 PCIe 作为上层协议——Chiplet 可直接暴露为 CXL 内存扩展或 PCIe 端点
- 面积和功耗预算分配是架构师核心约束：每 IP 的 PPA 特征矩阵在总预算内做帕累托最优分配

## 与其他概念的关系

- [[architecture/concepts/on-chip-bus|片上总线（On-Chip Bus）]] — 互连是 SoC 的"神经系统"，NoC 和 AXI 互连矩阵决定 IP 间通信的带宽和延迟
- [[architecture/concepts/memory-hierarchy|存储层次（Memory Hierarchy）]] — SLC 和内存控制器是 SoC 存储子系统的顶层，服务异构多核的差异化访问需求
- [[architecture/concepts/cache-coherence|缓存一致性（Cache Coherence）]] — Chiplet 跨晶粒一致性需扩展传统协议，CHI CML（Chiplet Mode Link）专门支持 D2D 接口
- [[concepts/cmos-fundamentals|CMOS 基础]] — 工艺节点的选择直接影响 SoC 的 PPA（Power-Performance-Area），先进工艺密度高但泄露功耗更显著
