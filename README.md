---
type: spec
aliases:
  - README_项目总览
  - 项目总览
tags:
  - asic
  - readme
  - overview
source_spec: "Local vault documentation"
queries: 1
---
# 数字IC知识库

数字集成电路（Digital Integrated Circuit）设计全栈知识库，覆盖从 RTL 编码到 GDSII 签核的完整 ASIC 流程。

## 目录结构

```
ic/                                          ← Obsidian Vault 根目录
├── README.md                                ← 本文件：项目总览与导航
├── 数字IC入口.md                             ← 知识库总入口 + 全库高频查询排名表
├── CLAUDE.md                                ← 项目规则（10 条硬性规则）
│
├── concepts/                                ← 数字IC基础概念
│   └── concepts/
│       ├── CMOS基础.md                      CMOS 工艺：NMOS/PMOS、逻辑门、功耗组成、工艺缩放
│       ├── 半导体基础.md                    半导体物理：能带、掺杂、PN 结、MOSFET、PVT 变异
│       ├── 亚稳态.md                        亚稳态：物理机理、MTBF 公式、同步器设计、准稳态
│       └── 数制.md                          数制表示：二进制、补码、定点数、浮点数、格雷码
│
├── rtl-design/                              ← RTL 设计领域
│   ├── RTL设计.md                           领域入口：概念索引、学习路径、高频查询排名
│   └── concepts/
│       ├── Verilog-HDL.md                   Verilog HDL：wire/reg、阻塞/非阻塞、可综合子集、FIFO
│       ├── SystemVerilog.md                 SystemVerilog：always_ff/comb/latch、可综合边界、logic
│       ├── 组合逻辑.md                      组合逻辑：assign vs always_comb、毛刺、冒险、扇入扇出
│       ├── 时序逻辑.md                      时序逻辑：D-FF、setup/hold、同步/异步复位、锁存器、分频器
│       ├── 时钟信号使用规范.md              时钟使用规范：门控/分频/切换、ICG、毛刺时钟反例
│       ├── 有限状态机.md                    有限状态机：Moore/Mealy、三段式编码、序列检测器
│       ├── 经典设计题例.md                  经典设计题：序列检测器、边沿检测、售货机
│       ├── 流水线设计.md                    RTL 流水线：Skid Buffer、吞吐率/延迟权衡、Valid-Ready
│       ├── 跨时钟域设计.md                  RTL CDC：2-FF 同步器、异步 FIFO、格雷码、握手协议
│       ├── 算术电路.md                      算术电路：半加器/全加器、RCA/CLA、计数器、移位寄存器
│       ├── DSP算法IP.md                     DSP 算法 IP：FIR、CORDIC、除法器
│       ├── 编码风格.md                      RTL 编码风格：命名规范、可综合清单、Lint 规则
│       ├── FIFO设计.md                      同步/异步 FIFO：空满判断、格雷码指针、FWFT、反压水线
│       ├── 仲裁器设计.md                    仲裁器设计：固定优先级/RR/加权/矩阵仲裁、PPA 权衡
│       └── 位图分配器与空闲链表.md           位图 vs 空闲链表：两级 FFZ 查找、逐维对比、重命名互补用法
│
├── verification/                            ← 功能验证领域
│   ├── 功能验证.md                          领域入口：验证方法论、学习路径、高频查询排名
│   └── concepts/
│       ├── UVM方法学.md                     UVM：Phase 机制、Factory、TLM、Sequence、RAL、Callback
│       ├── SVA断言.md                       SVA：即时/并发断言、property、蕴含算子、bind、Checker
│       ├── 覆盖率模型.md                    覆盖率：代码覆盖 vs 功能覆盖、covergroup、CDV
│       ├── 约束随机验证.md                  约束随机：rand/randc、constraint、dist、soft constraint
│       ├── 形式验证.md                      形式验证：属性检查、等价性检查、BMC、k-归纳
│       ├── 验证平台架构.md                  验证平台：分层 testbench、Agent、Scoreboard、Reference Model
│       └── 仿真加速与CRDB.md                仿真加速：Siloti C 模型、Replay Simulation、CRDB 数据库
│
├── architecture/                            ← 计算机体系结构领域
│   ├── 体系结构.md                          领域入口：处理器架构概念索引、高频查询排名
│   └── concepts/
│       ├── 指令流水线.md                    指令流水线：五级流水、数据冒险、控制冒险、流水线冒险
│       ├── 乱序执行.md                      乱序执行：Tomasulo、寄存器重命名、ROB、超标量
│       ├── 分支预测.md                      分支预测：BHT、GShare、TAGE、BTB、RAS
│       ├── 缓存一致性.md                    缓存一致性：MSI/MESI/MOESI、snooping vs directory
│       ├── 存储层次.md                      Cache 组织、MMU、TLB、虚拟内存、SRAM/DRAM/Flash
│       ├── 片上总线.md                      AXI4/AXI5 五通道、AHB/APB、outstanding、QoS、interconnect
│       ├── SoC架构.md                       SoC 架构：异构多核、Die-to-Die、Chiplet
│       ├── DMA与中断.md                     DMA 控制器、中断向量表、NVIC
│       ├── 指令集架构基础.md                冯·诺依曼/哈佛、RISC/CISC
│       └── 外设总线协议.md                  DDR、SPI、I2C、PCIe
│
├── asic-flow/                               ← ASIC 实现流程领域
│   ├── ASIC流程.md                          领域入口：RTL→GDSII 全流程、高频查询排名
│   └── concepts/
│       ├── 逻辑综合.md                      综合：三阶段、SDC 约束、技术映射、面积速度权衡
│       ├── RTL与网表.md                     RTL vs 网表：作用联系区别、网表五维分类、生命周期
│       ├── 后端支持BES.md                   BES：中端岗位、综合/DFT/LEC/STA/功耗/网表交付
│       ├── 静态时序分析.md                  STA：setup/hold、时钟定义、MCMM、OCV、false path
│       ├── 可测试性设计.md                  DFT：Scan Chain、ATPG、MBIST/LBIST、JTAG
│       ├── 时钟树综合.md                    CTS：H-tree、Useful Skew、Skew vs Latency
│       ├── 2D与3D网表.md                    网表：2D 单 Die vs 3D-IC 堆叠、TSV、跨 Die 分析
│       ├── 布局布线.md                      物理设计：Floorplan、Place、CTS insert、Route、ECO
│       ├── 功耗分析.md                      功耗：动态/静态、Clock/Power Gating、DVFS、SPEF 反标
│       ├── 签核.md                          Signoff：时序签核、IR Drop、EM、LEC
│       └── 物理验证.md                      物理验证：DRC、LVS、ERC、Antenna、DFM
│
├── cross-domain/                            ← 跨领域交叉概念
│   ├── 跨领域.md                            领域入口：系统性工程问题、高频查询排名
│   └── concepts/
│       ├── 时序收敛.md                      时序收敛：RTL→Signoff 迭代闭环、OCV→LVF
│       ├── 低功耗设计.md                    低功耗：UPF、Power Domain、Multi-Vth、ICG、AVS
│       ├── 跨时钟域设计.md                  CDC 全貌：MTBF、同步器策略、CDC 验证、SDC 约束
│       ├── 复位策略.md                      复位：同步 vs 异步、Reset Tree、复位域
│       ├── 反标.md                          反标：SPEF/SDF/活动数据回填、名称匹配、理想→真实切换
│       └── 信号完整性.md                    信号完整性：过冲/振铃、反射机理、端接匹配
│
├── tools/                                   ← 工具与脚本
│   ├── 工具与脚本.md                        领域入口：Makefile 讲义、脚本实战、高频查询排名
│   ├── render_wavedrom.sh                   Wavedrom 渲染脚本：.json → .html + .svg
│   └── concepts/
│       ├── 01-25-Makefile讲义（25 篇）.md    Makefile 系统讲义：规则/变量/函数/实战/错误50例
│       ├── C语言在数字IC中的应用.md         C 语言：位运算、指针与链表、宏、volatile
│       ├── TCL脚本实战.md                   TCL：变量/命令替换、proc、集合遍历、综合脚本
│       ├── Python脚本实战.md                Python：报告解析、批量改写、数据聚合
│       ├── Shell脚本实战.md                 Shell：退出码/set -e、回归驱动、流程胶水
│       ├── Perl脚本实战.md                  Perl：单行处理 -n/-p/-e、正则、存量脚本
│       └── Wavedrom绘制规则.md              Wavedrom：WaveJSON 字符语义、五条绘制规则
│
├── review/                                  ← 复习自测题库
│   ├── 复习自测入口.md                      自测入口：章节索引、待补考点清单
│   ├── RTL设计自测题.md                     RTL 自测：亚稳态/CDC、FIFO、FSM、流水线
│   ├── 功能验证自测题.md                    验证自测：UVM、SVA、覆盖率、形式验证
│   ├── 体系结构自测题.md                    架构自测：流水线、乱序、Cache、总线
│   ├── ASIC流程自测题.md                    ASIC 自测：综合、STA、DFT、功耗、签核
│   ├── 跨领域自测题.md                      跨领域自测：时序收敛、低功耗、复位、反标
│   ├── 基础概念自测题.md                    基础自测：CMOS、功耗公式、亚稳态、数制
│   ├── 工具脚本自测题.md                    工具自测：Makefile、C、TCL/Python/Shell/Perl、Wavedrom
│   └── 编程自测题.md                        编程自测：FIFO、分频、格雷码、握手
│
├── projects/                                ← 外部参考项目（.gitignore，不跟踪）
│   ├── uvm-memory/                          Memory Design UVM — 分4阶段教学项目
│   └── uvm-axi/                             AXI4 Interconnect UVM — 生产级验证项目
│
└── .obsidian/                               ← Obsidian 配置
    ├── app.json                             spellcheck、文件类型、主题
    ├── graph.json                           图谱着色规则
    └── snippets/                            CSS 代码片段
```

## 文件统计

| 类别 | 数量 | 说明 |
|:---|:---|:---|
| 入口与规则 | 4 | 数字IC入口.md、CLAUDE.md、README.md、PLAN.md |
| 基础概念 | 5 | CMOS、半导体、亚稳态、数制、斯密特触发器 |
| RTL 设计 | 1 MOC + 14 概念 | Verilog/SV、组合/时序逻辑、FSM、流水线、CDC、算术、编码、FIFO、时钟规范、DSP、经典题例、仲裁器设计 |
| 功能验证 | 1 MOC + 8 概念 | UVM、SVA、覆盖率、CRV、形式验证、平台、仿真加速、DPI-C |
| 体系结构 | 1 MOC + 12 概念 | 流水线、乱序、分支预测、Cache、总线、DMA/中断、SoC、ISA、外设、PCIe、DDR PHY、存储层次 |
| ASIC 流程 | 1 MOC + 12 概念 | 综合、RTL与网表、BES、STA、DFT、CTS、2D/3D网表、P&R、功耗、签核、PV、LEC |
| 跨领域 | 1 MOC + 6 概念 | 时序收敛、低功耗、CDC、复位、反标、信号完整性 |
| 工具与脚本 | 1 MOC + 31 概念 | Makefile 25 篇、C 语言、TCL/Python/Shell/Perl 实战、Wavedrom 绘制规则 |
| 复习自测 | 9 | 入口 + 8 个分领域题集 |
| 外部项目 | 2 | uvm-memory、uvm-axi（参考项目目录，不计入合计） |
| **合计** | **107 文件** | |

> docs/（9 篇内部过程文档）与 .obsidian/、assets/ 图片资产不计入本统计。

> docs/（9 篇内部过程文档）与 .obsidian/、assets/ 图片资产不计入本统计。

## 文件元数据

每个概念文件 frontmatter 包含以下字段：

| 字段 | 用途 | 示例 |
|:---|:---|:---|
| `type` | 文件分类：`concept`/`moc`/`index`/`spec` | `type: concept` |
| `aliases` | 别名列表，支持中英文搜索 | `Static Timing Analysis_静态时序分析` |
| `tags` | 领域标签，供图谱着色和数据检索 | `asic, sta, timing` |
| `source_spec` | 参考来源（标准/教材/论文），不可为空 | `IEEE 1800-2017` |
| `queries` | 问答管道查询计数，驱动高频排名 | `queries: 12` |

## Obsidian 图谱配置

全局 Graph 视图按 `type` 元数据分组着色：

| type | 颜色 | 用途 |
|:---|:---|:---|
| `index` | 红 | 入口页面（数字IC入口） |
| `moc` | 橙 | 领域内容地图 |
| `concept` | 蓝 | 核心概念 |
| `spec` | 绿 | 项目规范与规则 |

## 相关资源

- **数字IC设计常见问答**：`~/Downloads/数字IC设计常见面试题.md`
- **3GPP LTE/NR 译码链路**：独立 Obsidian vault（`~/AGENT/obsidian/3gpp/`）
- **Gitee 仓库**：[https://gitee.com/aurorayaus/ic](https://gitee.com/aurorayaus/ic)

## 维护说明

- **新增概念**：放在对应领域的 `concepts/` 下，文件名中文，frontmatter 包含 `queries: 1`
- **新增领域**：创建目录 + MOC 入口文件
- **跨领域概念**：放入 `cross-domain/concepts/`
- **文件规范**：详见 `CLAUDE.md`
- **外部项目**：放入 `projects/`，由 `.gitignore` 排除不跟踪
