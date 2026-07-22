---
type: concept
aliases:
  - 片上总线
  - On-Chip Bus
  - NoC
  - 片上网络
  - 片上互连
tags:
  - asic
  - architecture
  - bus
  - interconnect
source_spec: "AMBA AXI and ACE Protocol Specification (ARM IHI 0022); AMBA CHI Architecture Specification (ARM IHI 0050); Dally & Towles, Principles and Practices of Interconnection Networks"
---

# 片上总线协议（On-Chip Bus Protocols）

片上总线是 SoC 内部 IP 模块间数据传输的骨干通道。从简单共享总线到分组交换网络（NoC），片上互连技术随 SoC 规模从单主从微控制器演进到数十核异构系统的过程而持续发展。

## 原理

### AXI4/AXI5 五通道模型

AMBA AXI4 是 SoC 互连的事实标准，使用五个独立单向通道：写地址（AW — AWID, AWADDR, AWLEN, AWSIZE, AWBURST）、写数据（W — WDATA, WSTRB, WLAST）、写响应（B — BID, BRESP）、读地址（AR — ARID, ARADDR, ARLEN, ARSIZE, ARBURST）、读数据（R — RID, RDATA, RRESP, RLAST）。每通道独立 VALID/READY 握手——发送方置 VALID、接收方置 READY，同时为高时发生一拍传输。AXI5 增加了原子操作、唤醒信号（WAKEUP）、奇偶校验和独占访问增强。五通道的读写完全解耦——写事务流水（AW+W+B）和读事务流水（AR+R）可并行进行而互不阻塞。

### 事务管理、乱序完成与突发类型

未完成事务（Outstanding Transaction）：AXI 通过 AxID 标签支持最多 256 个同时飞行的未完成事务——同一 ID 的事务严格按序返回（保序），不同 ID 的事务可乱序完成（允许重排），慢事务不阻塞快事务。此机制是实现 MLP 的硬件基础。突发类型（Burst Type）：FIXED（地址不变，FIFO 式访问）、INCR（地址递增，常规连续访问）、WRAP（递增到边界后回绕，用于缓存行填充）。

### AHB 与 APB

AHB（Advanced High-performance Bus）为共享总线架构，单次传输需仲裁，2-3 级流水线，吞吐率固定于仲裁延迟和位宽。AXI 通过分离通道和乱序支持，同频下带宽可达 AHB 的 5-10 倍。AHB-Lite 简化单主场景。APB（Advanced Peripheral Bus）为简单非流水外设总线——无 VALID/READY 流水能力，每次传输两个时钟周期，专门用于低速寄存器配置，通过 AXI-to-APB 桥接入 AXI 子网。

### CHI 协议

CHI（Coherent Hub Interface）为多核一致性设计，将传输从信号级握手提升到包级消息。六条独立通道：TXREQ/TXRSP/TXDAT（发送）和 RXREQ/RXRSP/RXDAT（接收）。支持一致性事务（ReadShared, ReadUnique, CleanUnique, MakeUnique）和非一致性事务，通过分布式虚拟网络（VNET）区分请求、响应、侦听和数据流量优先级。一致性节点类型：RN-F（全一致性请求节点，如 CPU 簇）、HN-F（全一致性归属节点，如 LLC + 内存控制器）、RN-I（IO 一致性节点，如 GPU）。支持 DVM（Distributed Virtual Memory）用于 IOMMU/SMMU 的 TLB 失效广播。

### NoC 拓扑、路由与流控

当 IP 数量超 20-30 时，NoC 替代交叉开关。拓扑：Mesh（2D 网格最规整，网络直径 $O(\sqrt{N})$，布线友好）、Torus（Mesh 端点互连，减小直径并提高对分带宽）、Ring（低面积，适合少量节点）、Fat Tree（异构带宽层次）。路由：确定性 XY 路由（先 X 轴后 Y 轴，简单但负载不均衡）、自适应路由（根据拥塞动态选路，性能好但需防死锁）。交换/流控：存储转发（Store-and-Forward — 整包接收后再转发，延迟大）、虚拟直通（Virtual Cut-Through — 收到头部即开始转发，只需头微片缓冲）、虫洞交换（Wormhole — 微片流水线化，缓冲需求最小且延迟低，但头微片阻塞时整条链路被占用）。虚通道（Virtual Channel）为每个物理端口分配多个逻辑 FIFO，分离请求/响应流量防止协议级死锁，同时支持 QoS 优先级仲裁。

## 关键要点

- VALID-READY 握手是 AXI 最基础的同步原语——任何一方可独立等待，禁止组合逻辑环路
- 乱序完成（OOO）通过 AxID 实现：同 ID 保序、不同 ID 乱序——是 MLP 和多事务并发的关键
- AXI4-Stream 是 AXI 点对点流变体（仅 TDATA + TVALID + TREADY），用于 DSP 管道、视频流等无地址的流数据路径
- CHI 的点对点一致性消息（SnpShared/SnpClean/SnpOnce 等）替代传统总线广播侦听，可扩展至数十个一致性节点
- NoC 死锁避免的核心策略：虚通道分离请求/响应流量 + 严格的路由限制（如无回环的路由算法）
- 虫洞交换以微片为最小传输单位（Flit — FLow control unIT），头微片（Head Flit）携带路由信息，体尾微片（Body/Tail Flit）仅携带数据
- 接口位宽 $\times$ 时钟频率 = 单向峰值带宽：64-bit AXI @ 1GHz = 8 GB/s 单向，读写合计 16 GB/s
- 服务质量（QoS）通过虚拟网络优先级和令牌桶速率限制保证实时 IP（显示器、音频）的带宽和延迟上限

## 与其他概念的关系

- [[architecture/concepts/cache-coherence|缓存一致性（Cache Coherence）]] — CHI 协议直接承载一致性目录协议的点对点消息，是缓存一致性的硬件传输载体
- [[architecture/concepts/memory-hierarchy|存储层次（Memory Hierarchy）]] — AXI 的未完成事务数和乱序完成能力直接限制缓存缺失时 MLP 的有效发挥上限
- [[architecture/concepts/soc-architecture|SoC 架构]] — NoC 和总线互连是 SoC 架构的"神经系统"，决定了 IP 间通信的延迟分布和带宽矩阵
- [[rtl-design/concepts/verilog-hdl|Verilog HDL 入门]] — AXI 接口的 RTL 实现涉及 valid-ready 状态机、FIFO 缓冲和时序收敛，是 RTL 设计的高频考察场景
