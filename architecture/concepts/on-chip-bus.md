---
type: concept
aliases:
  - 片上总线
  - On-Chip Bus
  - AXI
  - AMBA
  - CHI
  - NoC
  - Network-on-Chip
tags:
  - asic
  - architecture
  - bus
  - interconnect
source_spec: "ARM AMBA AXI and ACE Protocol Specification (IHI0022); ARM AMBA CHI Specification (IHI0050); Dally & Towles, Principles and Practices of Interconnection Networks; ARM AMBA AHB/APB Specification"
---

# 片上总线与互连（On-Chip Bus & Interconnect）

片上总线是 SoC 内部各 IP 模块之间数据传输的核心基础设施。从简单的 AHB/APB 外设总线到高带宽的 AXI4/AXI5 多通道协议，再到支持缓存一致性的大规模 CHI（Coherent Hub Interface）协议和片上网络（NoC），片上互连的演进直接反映了 SoC 规模从单核 MCU 到百核异构计算的跨越。

## 原理

### AXI4/AXI5 五通道模型

AXI（Advanced eXtensible Interface）是 ARM AMBA 规范中面向高性能的片上总线协议，核心设计为五通道独立模型：写地址通道（Write Address, AW）、写数据通道（Write Data, W）、写响应通道（Write Response, B）、读地址通道（Read Address, AR）、读数据通道（Read Data, R）。五个通道完全独立，各自拥有独立的 VALID/READY 握手、单向传输。这种分离设计使读写操作完全并行——一个主设备可同时发出多个未完成读请求和写请求而互不阻塞。AXI5 在 AXI4 基础上增加了原子操作（AtomicCompare、AtomicLoad）、分组缓存属性（Allocate）和增强 QoS 信号。

### VALID/READY 握手机制

AXI 每个通道采用全双工双线握手：发送方拉高 VALID 表示信息有效，接收方拉高 READY 表示可接收。传输仅在 VALID 与 READY 同时为高的时钟上升沿发生。分离握手允许三种时序：（1）发送方先就绪——VALID 先断言，等待 READY；（2）接收方先就绪——READY 先断言，等待 VALID；（3）双方同时就绪——单周期完成。关键约束：发送方一旦断言 VALID 就不能撤销（不可反悔），必须等待握手完成；接收方可在 VALID 未断言时自由改变 READY。这种机制天然支持反压（Backpressure）——接收方拉低 READY 暂停数据流。

### Outstanding Transactions 与 Out-of-Order Completion

AXI 通过事务 ID（AWID/ARID）支持多个未完成事务和乱序完成。每个事务由 ID 标识——同 ID 事务须按序完成，不同 ID 事务可按任意顺序完成。互连网络内部可自由调度事务以最大化带宽利用率，主设备通过为独立数据流分配不同 ID 来容忍延迟差异。事务 ID 宽度（通常 4-8 位，即 16-256 个 ID）决定最大未完成事务数。写响应（B 通道 BID）必须匹配 AWID；读数据（R 通道 RID）必须匹配 ARID。

### Burst 类型与 AHB/APB 对比

AXI 支持三种突发类型（AWBURST/ARBURST）：FIXED——所有 beat 针对同一地址（如 FIFO 寄存器）；INCR（Incrementing）——地址按传输大小递增，最常用；WRAP（Wrapping）——地址在突发边界内环绕（如缓存行填充从任意偏移开始贯穿 64B 行）。Burst Length 支持 1-16（AXI4）或 1-256（AXI5）；Burst Size 从 1B 到 128B。

AHB（Advanced High-performance Bus）采用共享地址/数据总线、流水线传输，不支持 Outstanding Transaction 和 Out-of-Order Completion，每次突发期间总线独占。APB（Advanced Peripheral Bus）是最简低速外设总线：非流水、两周期一传输、无突发、单主设备（APB Bridge），用于 GPIO、UART、I2C 等。

### CHI 协议分层架构

CHI（Coherent Hub Interface）是 ARM 为大规模一致性互连设计的分层协议，用于替代 ACE（AXI Coherency Extensions）以支持 64+ 核心系统。CHI 分为三层：（1）协议层（Protocol Layer）——定义一致性事务的消息类型和状态转换，包括四类消息通道（Request/Response/Snoop/Data），支持全套一致性操作（ReadUnique、ReadShared、CleanUnique 等）；（2）链路层（Link Layer）——负责基于信用的流控（Credit-based Flow Control）、数据完整性（CRC/Parity）、Flit 打包/解包；（3）物理层（Physical Layer）——定义信号电气特性和 PHY 时序。CHI 基于报文（Packet）通信而非 AXI 的基于周期（Cycle）信令，事务打包为 Flit 传输，支持数千个未完成事务。

### NoC 拓扑与路由

片上网络（Network-on-Chip, NoC）在 IP 数量超过数十个时替代 Crossbar 以解决可扩展性瓶颈。常见拓扑：2D Mesh——每路由器连接四方向邻居和一个本地 IP，布线规整；Concentrated Mesh——每路由器服务 4 个本地 IP 减少路由器数；Torus——Mesh 变体，边缘节点环绕相连减少平均跳数；Ring——简单但平均跳数大。路由策略：确定性（X-Y 维序路由，无死锁但无法避拥塞）和自适应（根据拥塞动态选路）。流量控制采用虫洞路由（Wormhole Routing）——数据包切分为 Flit，流水线传递不等整个包收完，极大减少缓冲需求。虚拟通道（Virtual Channel, VC）为每条物理链路提供多组独立缓冲（2-4 VC），消除 Head-of-Line Blocking 并用于构建无死锁虚网络。

### AXI Interconnect 的设计要点

AXI Interconnect（也称 AXI Fabric）是连接多个主从设备的核心基础设施，本质是多路复用的数据通路和地址解码器。关键设计要素包括：地址解码——根据 AxADDR 和可编程地址映射表将事务路由到目标从设备；仲裁——多主竞争同一从时按优先级（固定/轮询/LRU）选出一方获得访问权；事务重排——根据 AxID 维护事务顺序（同 ID 保序，不同 ID 可重排，需重排缓冲区）。

服务质量通过 AxQOS 信号实现：每个主设备事务携带 QoS 标签（通常 4 位，16 个优先级），互连内部按优先级仲裁——高优先级实时事务优先于低优先级批量事务。为防止饿死，低优先级事务等待时间增长时其优先级逐渐提升（Aging 机制）。AXI Interconnect 还需处理数据宽度转换：当主设备数据宽度（256-bit）与从设备（64-bit）不匹配时，需将宽 beat 拆分为多个窄 beat（Downsizing），或将窄 beat 合并为宽 beat（Upsizing）。长突发的拆分与合并是互连时序的关键路径。

## 关键要点

- AXI 五通道独立使读写完全并行，单个主设备可达接近理论峰值的总线带宽利用率
- VALID/READY 分离握手天然支持反压，无需额外流控信号；发送方不可反悔、接收方可自由改变 READY
- Outstanding Transaction 和 Out-of-Order Completion 是高性能互连的标志——AHB 和 APB 均不支持
- WRAP 突发是缓存行填充的标准用法：从缺失地址环绕填充 64B 行，关键字节（Critical Word）最先返回
- ACE 在 AXI 五通道外增加两个 Snoop 通道实现总线侦听式一致性
- CHI 从基于周期改为基于报文通信，Credit-based 流控比 AXI READY 握手更适合长物理链路
- 虫洞路由缓冲需求 = 链路深度 * VC 数 * Flit 位宽（而非整包大小 * 跳数）
- 虚通道隔离：控制类消息（Snoop、Response）用高优先级 VC，不被数据流量阻塞
- NoC 死锁避免：转弯禁止算法（Turn-Prohibition）或按序分配虚网络（Escaping VCs）

## 与其他概念的关系

- [[architecture/concepts/cache-coherence|缓存一致性（Cache Coherence）]] — 目录式协议的四类消息通过 CHI Request/Response/Snoop/Data 通道承载，CHI 序列化点对应归属节点目录查找
- [[architecture/concepts/memory-hierarchy|存储层次（Memory Hierarchy）]] — 缓存缺失产生的访存请求通过 AXI/CHI 逐级传递至 DRAM 控制器，总线延迟直接贡献 miss_penalty
- [[architecture/concepts/soc-architecture|SoC 架构（SoC Architecture）]] — 互连拓扑和协议选择是 SoC 架构设计的核心决策，直接影响带宽分配和 IP 集成方案
- [[cross-domain/clock-domain-crossing|跨时钟域（CDC）]] — NoC 中不同电压/频率域之间的路由器链路需要异步 FIFO 桥接
