---
type: concept
aliases:
  - DDR Interface and PHY Training_DDR接口与PHY训练
  - DDR PHY
tags:
  - asic
  - architecture
  - memory
source_spec: "JEDEC JESD79（DDR3/DDR4/DDR5 标准）；Jacob et al., Memory Systems: Cache, DRAM, Disk"
queries: 1
---
# DDR接口与PHY训练

DDR（Double Data Rate，双倍数据率）SDRAM 是处理器主存的存储接口——时钟上升沿与下降沿都传输数据（DDR 的由来）。系统视角的分层是：**内存控制器（Memory Controller）→ PHY（物理层接口）→ DRAM 颗粒**。PHY 是控制器与 DRAM 之间的物理适配层——完成高速并行信号的收发、时序训练与校准。DRAM 的层次角色（与 SRAM/Cache 的对比）见 [[architecture/concepts/存储层次|存储层次]]，总线族谱的概览见 [[architecture/concepts/外设总线协议|外设总线协议]]；本文聚焦 PHY 的工程核心：时序参数、训练流程与校准。

## 原理

### 接口信号与时序参数

DDR 接口的关键信号：**CK/CK#**（差分时钟）、**CKE**（时钟使能）、**CS#**（片选）、**命令总线（RAS#/CAS#/WE#）**、**地址总线（A/BA 复用行列地址与 Bank 地址）**、**DQ（数据，双向）×8/×16/×32**、**DQS（数据选通，与数据同向传输的差分信号）**、**DM（数据掩码）**。DQ 是源同步（Source Synchronous）接口——写方向 DQS 由控制器发、读方向 DQS 由 DRAM 发，接收方用对方随附的 DQS 采样 DQ，而不是用本地时钟。

核心时序参数（以时钟周期为单位，DDR4 典型值）：**tRCD**（行激活到列读写的延迟）、**tCL/CAS Latency**（列命令到数据返回的延迟）、**tRP**（预充电到下一激活的间隔）、**tRAS**（激活到预充电的最小间隔）——面试速记："激活一行（tRCD）→ 读数据（tCL）→ 预充电（tRP）→ 再激活"。**刷新（Refresh）**：DRAM 电容漏电，每 64ms（tREFI 周期）内必须对所有行刷新一遍——控制器按 tREFI 周期性发 REF 命令，刷新期间不能访问。

### 为什么需要训练：信号到达时间不相等

DDR 高速下（DDR4 2400MT/s 以上），信号走线长度的微小差异就会造成到达时间偏差：同一字节内的 8 根 DQ 到达 PHY 的时间不同（走线偏差 + DRAM 输出偏差）、写方向 PHY 发出的 DQS 与 CK 到达 DRAM 的时间关系未知、不同字节通道（Byte Lane）之间也各不相同。**训练（Training）的职责就是测量这些偏差并用延迟补偿**——PHY 内含每通道可编程的延迟线（Delay Line），上电后执行一系列训练流程标定补偿值。不训练的直接后果：采样窗口偏离数据眼图中心，出现读写错误。

### 三类核心训练

**（1）Write Leveling（写均衡）**：对齐 DQS 与 CK 到 DRAM 的到达时间。目的：DRAM 写数据用 DQS 采样，而写命令用 CK 采样——两者到达 DRAM 必须满足写时序窗口。流程：控制器发一个 DQS 脉冲，DRAM 采样 CK 电平经 DQ 反馈回来，控制器逐档调节 DQS 延迟直到反馈翻转——记下该延迟档即为该字节的均衡值。**每字节通道独立执行**——各通道走线不同、延迟不同。

**（2）Read Training（读训练）**：对齐读返回数据的采样点。两个子任务：**读 DQS 门控（Read DQS Gate Training）**——找到 DQS 前导（Preamble）出现的时刻，据此打开 DQS 采样窗口（不在数据有效期间采样到总线空闲的悬空态）；**读数据眼图训练（Read Data Eye Training）**——扫描 DQS/DQ 的相对延迟，把采样点放在数据眼图的中心（眼宽最大的位置），确定每根 DQ 的最佳采样延迟。DDR4/DDR5 的每通道独立参考电压（Vref Training）也在此阶段标定。

**（3）ZQ 校准（ZQ Calibration）**：校准输出阻抗与片上终结（ODT, On-Die Termination）电阻。DRAM 输出驱动阻抗与终结电阻随工艺/温度/电压漂移——ZQ 引脚外接精密电阻（240Ω ±1%），DRAM 内部逐档调节可编程电阻阵列逼近该基准值。**上电校准 + 运行中周期性重校准**（温度漂移补偿）——信号完整性（反射与眼图质量）直接依赖阻抗匹配。

### 训练的执行与系统集成

训练由内存控制器主导、在初始化阶段执行——每次上电、每次休眠唤醒（自刷新退出）后都要重跑；温度大幅漂移时（>10°C 量级）需要重校准 ZQ。训练对软件透明：Boot ROM/固件初始化控制器 → 控制器依次执行 ZQ → Write Leveling → Read Gate → Read Eye → 进入正常工作状态。**验证视角**：PHY 训练的验证在 SoC 层面以 BIST 形式覆盖（内置自测读写比对），训练收敛性（延迟档收敛到稳定值）是 PHY 验证的关键指标；控制器与 PHY 的配合（命令时序、刷新调度）见 [[architecture/concepts/存储层次|存储层次]] 的访存链。

## 关键要点

- **DQS 源同步接口**：读方向 DQS 由 DRAM 发出——接收方用对方随附的 DQS 采样 DQ 而非本地时钟，这是训练存在的前提
- **训练补偿的是到达时间偏差**：走线偏差 + 器件偏差使同字节各 DQ 到达时间不同——每通道延迟线逐档标定
- **Write Leveling 对齐 DQS 与 CK 到 DRAM**：写命令用 CK、写数据用 DQS——两者到 DRAM 必须满足写时序窗口
- **Read Training 分两步**：DQS 门控找到数据前导时刻、眼图训练把采样点放眼图中心
- **ZQ 校准阻抗**：外接 240Ω 精密基准 + 片上可编程阵列——上电校准 + 温度漂移周期重校准
- **训练时机**：每次上电与自刷新唤醒必跑——Boot 固件初始化控制器后依次执行，对软件透明
- **时序参数速记**：tRCD 激活到列、tCL 列到数据、tRP 预充电、tRAS 行激活窗口、tREFI 刷新间隔

## 与其他概念的关系

- [[architecture/concepts/存储层次|存储层次]] — DRAM 在存储金字塔的位置：容量/延迟/带宽的平衡与刷新代价
- [[architecture/concepts/外设总线协议|外设总线协议]] — DDR 与 PCIe/SPI/I2C 的分工概览：主存带宽 vs 外设互联
- [[architecture/concepts/SoC架构|SoC架构]] — 内存控制器与 PHY 在 SoC 中的集成：物理层训练对 Boot 固件的依赖
- [[asic-flow/concepts/签核|签核]] — PHY 的时序签核：源同步接口的时序分析与时序窗口约束
