---
type: index
aliases:
  - Digital IC Hub_数字IC知识库
  - ASIC Knowledge Base
  - 数字IC入口
tags:
  - asic
  - index
  - moc
source_spec: "Local vault index"
queries: 1
---
# 数字IC知识库

数字集成电路（Digital Integrated Circuit）设计全栈知识库，覆盖从 RTL 编码到 GDSII 签核的完整 ASIC 设计流程。

## 领域入口

| 领域 | 入口 | 核心主题 |
|:---|:---|:---|
| RTL 设计 | [[rtl-design/RTL设计\|RTL 设计 MOC]] | Verilog, SystemVerilog, FSM, CDC, 流水线 |
| 验证 | [[verification/功能验证\|验证 MOC]] | UVM, SVA, 覆盖率, 形式验证 |
| 体系结构 | [[architecture/体系结构\|体系结构 MOC]] | 流水线, 乱序执行, 缓存, 总线, SoC |
| ASIC 流程 | [[asic-flow/ASIC流程\|ASIC 流程 MOC]] | 综合, STA, DFT, 布局布线, Signoff |
| 工具与脚本 | [[tools/工具与脚本\|工具与脚本 MOC]] | Makefile 25 篇系统讲义, TCL, Perl/Python, Shell, Git, Wavedrom 波形绘制 |

## 跨领域概念

- [[cross-domain/跨领域|跨领域 MOC]] — 贯穿全流程的系统性工程问题总览
- [[cross-domain/concepts/时序收敛|时序收敛（Timing Closure）]] — 贯穿 RTL到Signoff 的核心闭环
- [[cross-domain/concepts/低功耗设计|低功耗设计（Low Power Design）]] — 从架构到物理实现的功耗优化
- [[cross-domain/concepts/跨时钟域设计|跨时钟域（Clock Domain Crossing）]] — 多时钟 SoC 的同步策略
- [[cross-domain/concepts/复位策略|复位策略（Reset Methodology）]] — 复位方案的选择与实现
- [[cross-domain/concepts/反标|反标（Back-Annotation）]] — SPEF/SDF/活动数据的跨阶段回填机制
- [[cross-domain/concepts/信号完整性|信号完整性（Signal Integrity）]] — 过冲/振铃/反射机理与端接匹配

## 基础概念

- [[concepts/CMOS基础|CMOS 基础]] — 数字IC的物理工艺基础
- [[concepts/数制|数字的数制表示]] — 二进制、补码、定点数、浮点数
- [[concepts/亚稳态|亚稳态（Metastability）]] — 跨时钟域问题的物理根源
- [[concepts/半导体基础|半导体基础]] — PN 结、MOSFET、PVT 变异
- [[concepts/斯密特触发器|斯密特触发器（Schmitt Trigger）]] — 迟滞阈值去噪、波形整形

## 复习自测

- [[review/复习自测入口|复习自测题库]] — 全栈自测题：分领域题目 + 要点提纲 + 出处链接，选题热度依据各领域高频查询排名表

## 关联知识库

- **3GPP LTE/NR 译码链路**（独立 Obsidian vault: `~/AGENT/obsidian/3gpp/`） — 通信基带协议与算法

## 项目规范

- [[CLAUDE|CLAUDE.md]] — 项目规则、术语规范与内容标准

## 全库高频查询（易忘知识点总排名）

按查询次数降序，跨领域汇总所有 MOC 高频查询条目。

| 总排名 | 领域 | 概念 | 查询次数 | 最后查询 |
|:---|:---|:---|:---|:---|
| 1 | ASIC 流程 | [[asic-flow/concepts/静态时序分析\|STA / Critical Path / Skew & Jitter / Multi-Cycle / False Path / Fmax / OCV]] | 14 | 2026-08-31 |
| 2 | 体系结构 | [[architecture/concepts/片上总线\|片上总线协议（AHB / APB / AXI / QoS / Interconnect）]] | 8 | 2026-07-23 |
| 3 | RTL 设计 | [[rtl-design/concepts/组合逻辑\|毛刺 / 异或门 / 竞争冒险 / 扇入扇出]] | 7 | 2026-07-23 |
| 4 | 跨领域 | [[cross-domain/concepts/低功耗设计\|时钟门控ICG / 操作数隔离 / 门控使能时序 / ICG强制使用策略 / ICG毛刺消除机制 / 功耗公式杠杆分类]] | 7 | 2026-08-12 |
| 5 | RTL 设计 | [[rtl-design/concepts/时序逻辑\|锁存器与触发器 / 同步异步电路 / 分频器]] | 5 | 2026-07-23 |
| 6 | 体系结构 | [[architecture/concepts/存储层次\|Cache 组织 / MMU / 虚拟内存]] | 4 | 2026-07-23 |
| 7 | 验证 | [[verification/concepts/验证平台架构\|数据比对策略：实时比对 vs 离线比对]] | 4 | 2026-08-11 |
| 8 | 基础概念 | [[concepts/亚稳态\|亚稳态 / MTBF / 准稳态]] | 3 | 2026-07-23 |
| 9 | RTL 设计 | [[rtl-design/concepts/SystemVerilog\|阻塞/非阻塞 / task-function / interface / 综合子集]] | 3 | 2026-07-23 |
| 10 | RTL 设计 | [[rtl-design/concepts/有限状态机\|一段/两段/三段式 / 状态编码 / 安全状态机]] | 3 | 2026-07-23 |
| 11 | RTL 设计 | [[rtl-design/concepts/跨时钟域设计\|异步FIFO / 多比特CDC / 格雷码 / 握手协议]] | 3 | 2026-07-23 |
| 12 | ASIC 流程 | [[asic-flow/concepts/逻辑综合\|面积速度权衡 / 资源共享 / Retiming]] | 3 | 2026-07-23 |
| 13 | 体系结构 | [[architecture/concepts/外设总线协议\|DDR / SPI / I2C / PCIe]] | 3 | 2026-07-23 |
| 14 | 跨领域 | [[cross-domain/concepts/跨时钟域设计\|时钟域分类 / CDC验证 / 同步器策略]] | 2 | 2026-07-23 |
| 15 | RTL 设计 | [[rtl-design/concepts/Verilog-HDL\|阻塞非阻塞赋值 / Scheduling队列 / 同步FIFO]] | 2 | 2026-07-23 |
| 16 | RTL 设计 | [[rtl-design/concepts/流水线设计\|加速比 / 效率 / 超标量 / 乱序执行]] | 2 | 2026-07-23 |
| 17 | ASIC 流程 | [[asic-flow/concepts/布局布线\|Floorplan / Placement / CTS / Routing]] | 2 | 2026-07-23 |
| 18 | 验证 | [[verification/concepts/SVA断言\|cover/assume/assert/property/sequence 区别]] | 2 | 2026-07-23 |
| 19 | 体系结构 | [[architecture/concepts/指令集架构基础\|冯·诺依曼 / 哈佛 / RISC / CISC]] | 2 | 2026-07-23 |
| 20 | 体系结构 | [[architecture/concepts/乱序执行\|乱序执行 / 超标量]] | 2 | 2026-07-23 |
| 21 | 体系结构 | [[architecture/concepts/DMA与中断\|DMA / 中断]] | 2 | 2026-07-23 |
| 22 | 验证 | [[verification/concepts/UVM方法学\|Monitor vs Scoreboard 职责与实现（被动观测 vs 主动判断）]] | 2 | 2026-08-11 |
| 23 | RTL 设计 | [[rtl-design/concepts/算术电路\|半加器/全加器/RCA/CLA/计数器/移位寄存器]] | 1 | 2026-07-23 |
| 24 | RTL 设计 | [[rtl-design/concepts/FIFO设计\|同步FIFO/异步FIFO/Gray码/FWFT/Almost Full/Empty/反压水线]] | 3 | 2026-09-02 |
| 25 | RTL 设计 | [[rtl-design/concepts/时钟信号使用规范\|时钟为何不能做逻辑操作 / 敏感列表 / ICG门控 / 分频与切换]] | 1 | 2026-08-12 |
| 26 | ASIC 流程 | [[asic-flow/concepts/时钟树综合\|CTS / Skew vs Latency / CTS前后时序差异]] | 1 | 2026-07-23 |
| 27 | ASIC 流程 | [[asic-flow/concepts/功耗分析\|功耗分析（功耗仿真 / VCD / SAIF / PTPX / What-If / FSDB转VCD / VDDC-VDDP分域 / SPEF与网表关系）]] | 10 | 2026-09-02 |
| 28 | 跨领域 | [[cross-domain/concepts/时序收敛\|时序收敛]] | 1 | 2026-07-23 |
| 29 | 跨领域 | [[cross-domain/concepts/复位策略\|复位策略]] | 1 | 2026-07-23 |
| 30 | 验证 | [[verification/concepts/覆盖率模型\|代码覆盖率 vs 功能覆盖率]] | 1 | 2026-07-23 |
| 31 | 验证 | [[verification/concepts/约束随机验证\|随机化约束写法]] | 1 | 2026-07-23 |
| 32 | 验证 | [[verification/concepts/验证平台架构\|验证计划制定与验证完备性]] | 1 | 2026-07-23 |
| 33 | 验证 | [[verification/concepts/验证平台架构\|Reference Model 作用]] | 1 | 2026-07-23 |
| 34 | 验证 | [[verification/concepts/SVA断言\|SVA握手协议断言]] | 1 | 2026-07-23 |
| 35 | 验证 | [[verification/concepts/UVM方法学\|UVM Phase 机制]] | 1 | 2026-07-23 |
| 36 | 验证 | [[verification/concepts/UVM方法学\|uvm_component vs uvm_object]] | 1 | 2026-07-23 |
| 37 | 验证 | [[verification/concepts/UVM方法学\|UVM Factory 机制]] | 1 | 2026-07-23 |
| 38 | 验证 | [[verification/concepts/UVM方法学\|TLM put/get/transport 接口]] | 1 | 2026-07-23 |
| 39 | 验证 | [[verification/concepts/UVM方法学\|Sequence/Sequencer/Driver 交互]] | 1 | 2026-07-23 |
| 40 | 验证 | [[verification/concepts/UVM方法学\|Virtual Interface 原理]] | 1 | 2026-07-23 |
| 41 | 验证 | [[verification/concepts/UVM方法学\|Register Model (RAL)]] | 1 | 2026-07-23 |
| 42 | 验证 | [[verification/concepts/UVM方法学\|Callback 机制]] | 1 | 2026-07-23 |
| 43 | 验证 | [[verification/concepts/UVM方法学\|uvm_do/uvm_do_with 宏详解]] | 1 | 2026-07-23 |
| 44 | 验证 | [[verification/concepts/UVM方法学\|get_next_item/item_done 握手协议]] | 1 | 2026-07-23 |
| 45 | 验证 | [[verification/concepts/UVM方法学\|raise_objection/drop_objection 机制]] | 1 | 2026-07-23 |
| 46 | 验证 | [[verification/concepts/UVM方法学\|uvm_info/uvm_error/uvm_fatal 详解]] | 1 | 2026-07-23 |
| 47 | 验证 | [[verification/concepts/UVM方法学\|config_db::set/get 详解]] | 1 | 2026-07-23 |
| 48 | 体系结构 | [[architecture/concepts/指令流水线\|流水线冒险]] | 1 | 2026-07-23 |
| 49 | 体系结构 | [[architecture/concepts/分支预测\|分支预测]] | 1 | 2026-07-23 |
| 50 | 体系结构 | [[architecture/concepts/缓存一致性\|缓存一致性（MESI）]] | 1 | 2026-07-23 |
| 51 | ASIC 流程 | [[asic-flow/concepts/后端支持BES\|后端支持（BES）]] | 1 | 2026-08-26 |
| 52 | 验证 | [[verification/concepts/仿真加速与CRDB\|仿真加速与 CRDB（Siloti）]] | 1 | 2026-08-26 |
| 53 | ASIC 流程 | [[asic-flow/concepts/2D与3D网表\|2D 网表与 3D 网表]] | 1 | 2026-08-26 |
| 54 | ASIC 流程 | [[asic-flow/concepts/RTL与网表\|RTL 与网表（作用 / 联系 / 区别 / 分类）]] | 2 | 2026-08-26 |
| 55 | ASIC 流程 | [[asic-flow/concepts/可测试性设计\|可测试性设计（DFT：扫描链 / ATPG / MBIST）]] | 3 | 2026-08-26 |
| 56 | 跨领域 | [[cross-domain/concepts/反标\|反标（Back-Annotation / SPEF / SDF / VCD 反标）]] | 1 | 2026-08-27 |
| 57 | 基础概念 | [[concepts/半导体基础\|半导体基础（迁移率与 Vth 温度竞争 / 温度反转 / 超频低温提速物理）]] | 2 | 2026-08-31 |
| 58 | 跨领域 | [[cross-domain/concepts/信号完整性\|信号完整性（过冲/振铃/反射机理/端接匹配）]] | 1 | 2026-09-02 |
| 59 | 工具与脚本 | [[tools/concepts/Wavedrom绘制规则\|Wavedrom 绘制规则（. 重复 / 标签挂 2 3 / = 禁用 / 数据框终止 / 三件套重渲染）]] | 1 | 2026-09-02 |

> 以上为全部 59 条高频查询的全量排名。计数仅含通过 Q&A Pipeline 统计的查询。
