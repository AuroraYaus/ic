---
type: concept
aliases:
  - PCIe Protocol_PCIe协议
  - PCI Express
tags:
  - asic
  - architecture
  - bus
source_spec: "PCI Express Base Specification 5.0/6.0 (PCI-SIG); Budruk et al., PCI Express System Architecture"
queries: 1
---
# PCIe协议

PCIe（Peripheral Component Interconnect Express，外围组件互连高速总线）是现代 SoC 与 PC 平台的高速外设互联标准——SSD（NVMe）、显卡、网卡、AI 加速卡都走 PCIe。它的设计哲学是**点对点串行 + 分层协议 + 报文交换**：与并行共享总线（PCI 的地址/数据复用并行总线）相比，串行差分对没有并行偏斜问题、点对点没有仲裁问题、分层协议让速率演进（Gen1 2.5GT/s → Gen6 64GT/s）不改变上层语义。概览级的对比（与 DDR/SPI/I2C 的分工）见 [[architecture/concepts/外设总线协议|外设总线协议]]，本文聚焦协议细节：三层结构、TLP/DLLP、流量控制、链路训练。

## 原理

### 三层结构：事务层 / 数据链路层 / 物理层

PCIe 的分层模型与 TCP/IP 同构——每层只与对等层对话，下层提供服务：

**事务层（Transaction Layer）**：产生与消费 TLP（Transaction Layer Packet，事务层报文）——TLP 携带地址/数据/完成信息，是协议的最高语义单位。事务类型：存储器读/写（Memory Read/Write）、IO 读/写、配置读/写（Config Read/Write）、消息（Message，中断等）。**TLP 头部格式**：64 位地址（或 32 位）+ 类型字段（Fmt/Type）+ 长度（10 位，最大 1024 双字即 4KB 读请求）+ 请求者 ID + 标签（Tag，用于区分 outstanding 事务）。

**数据链路层（Data Link Layer）**：负责链路级可靠传输——为 TLP 加序列号（Sequence Number）与 CRC（LCRC），用 ACK/NAK 协议重传损坏报文；同时产生与消费 DLLP（Data Link Layer Packet，数据链路层报文）——DLLP 是链路管理报文（ACK/NAK、流量控制更新、电源管理），只在相邻两端之间收发、不跨交换机。**重传机制**：接收方校验 LCRC 失败回 NAK 并丢弃，发送方从重传缓冲区（Replay Buffer）重发——错误重传是数据链路层的核心职责。

**物理层（Physical Layer）**：串行差分对的电气传输——8b/10b 编码（Gen1/2）或 128b/130b 编码（Gen3+）、加扰（Scrambling）保证直流平衡与时钟恢复、链路训练（LTSSM）。通道（Lane）是一对差分收发——链路宽度 x1/x2/x4/x8/x16 聚合多通道，字节在通道间条带化（Byte Striping）传输。

**层级数据流**：发送路径"TLP 生成 → 加序列号 + LCRC → 8b/10b 编码 → 串行化到通道"；接收路径逆序——每层剥离自己添加的部分，最终把干净 TLP 交给事务层。

### 流量控制：Credit 信用机制

PCIe 的流量控制（Flow Control）是**基于信用（Credit）的端到端反压**——与握手式（valid/ready）反压的本质区别：接收方**预先公告**自己的缓冲容量，发送方**持续跟踪**剩余额度，不必每个报文等确认。六类缓冲分类：Posted 头（PH）/Posted 数据（PD）/Non-Posted 头（NPH）/Non-Posted 数据（NPD）/完成头（CPLH）/完成数据（CPLD）。Posted 事务（存储器写、消息）不需要完成报文、可穿透交换机先行；Non-Posted（读请求）需要完成报文回报。

Credit 更新机制：初始化时交换各自的 Credit 总量（FC Init），运行中通过 DLLP 的 FC Update 报文周期性补回额度——接收方消费 TLP 腾出缓冲后必须及时补 Credit，否则发送方额度耗尽停止发送（链路饿死）。**死锁避免**：Posted 事务必须能穿透（不能因 Non-Posted 完成反压而阻塞）——缓冲耗尽时 Posted 报文仍须能吸收（这就是 Posted 与 Non-Posted 分池的原因）。

### 事务语义与完成机制

**Posted vs Non-Posted**：Posted（写、消息）单向无完成回报——低延迟、防死锁的关键；Non-Posted（读、配置写）必须返回完成报文（Completion）。**乱序完成**：读请求带 Tag 标签，多个 outstanding 读的完成可乱序返回——完成报文的 Tag 匹配请求。**请求者 ID 与路由**：TLP 经交换机（Switch）按地址路由（地址路由）、按总线号（ID 路由）、或隐式路由（消息按目的地隐式广播）——交换机维护上游/下游端口方向表。

**配置空间（Configuration Space）**：每个设备 4KB 配置空间——前 64 字节与 PCI 兼容（设备 ID/厂商 ID/基地址寄存器 BAR），其余为 PCIe 扩展能力（Capability）：链路能力、电源管理、MSI/MSI-X 中断向量。枚举（Enumeration）：系统软件扫描总线树、分配总线号/地址空间（BAR 编程）——设备在枚举完成后才能被寻址，这是驱动开发与验证平台的共同起点。

### 链路训练与状态机

LTSSM（Link Training and Status State Machine，链路训练状态机）管理链路从检测到正常工作的全部状态：Detect（检测对端存在）→ Polling（对齐与速率协商）→ Configuration（宽度协商 x1-x16）→ L0（正常工作状态）→ Recovery（错误后重训练）→ L0s/L1/L2（低功耗状态，依次更深）。训练过程通过有序集（Ordered Set，TS1/TS2 序列）交换能力并逐通道对齐——链路宽度/速率降级（如 x16 降 x8）是训练失败的常见结果。**均衡（Equalization）**：Gen3+ 在 Recovery 阶段执行发送端均衡参数协商——高速率的信号完整性靠发送端预加重与接收端均衡共同保证。

## 关键要点

- **三层结构各司其职**：事务层管 TLP 语义、数据链路层管可靠传输（序号 + LCRC + 重传）、物理层管编码与链路训练——速率演进不改变上层语义
- **TLP 与 DLLP 的分工**：TLP 跨设备传数据/配置/完成，DLLP 只在相邻两端（ACK/NAK、FC 更新、电源管理）
- **Credit 机制是预公告式反压**：六类缓冲分类、Posted 必须可穿透——与握手式反压的本质区别是无需逐报文确认
- **Posted/Non-Posted 语义**：写单向无完成（低延迟）、读必须完成回报（Tag 匹配乱序完成）
- **LTSSM 管链路生命周期**：Detect → Polling → Config → L0，速率/宽度协商失败即降级——低功耗状态 L0s/L1/L2 逐级加深
- **配置空间与枚举**：BAR 编程分配地址空间——设备枚举完成才能被寻址

## 与其他概念的关系

- [[architecture/concepts/外设总线协议|外设总线协议]] — PCIe 在总线族谱中的位置：与 DDR（主存）、SPI/I2C/UART（低速外设）的分工概览
- [[architecture/concepts/片上总线|片上总线]] — 片内 AXI 与片外 PCIe 的对比：乱序完成/Tag 匹配的语义同源、物理层完全不同
- [[architecture/concepts/DMA与中断|DMA与中断]] — PCIe 设备的数据搬运与中断：MSI/MSI-X 中断向量与 DMA 描述符的配合
- [[architecture/concepts/SoC架构|SoC架构]] — SoC 集成 PCIe 控制器的位置：根复合体（Root Complex）与端点（Endpoint）的角色划分
