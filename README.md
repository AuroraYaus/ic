# 数字IC知识库 — Vault 总览

> 数字集成电路（Digital IC）设计全栈知识库，覆盖从 RTL 编码到 GDSII 签核的完整 ASIC 流程。

## 目录结构与用途

```
ic/                                          ← Obsidian Vault 根目录
├── README.md                                ← 本文件：vault 总览与导航
├── 数字IC_入口.md                           ← 知识库总入口，MOC 辐射六大领域
├── CLAUDE.md                                ← 项目规则（术语、图表、代码、Wikilink、内容质量）
│
├── concepts/                                ← 数字IC基础概念（跨领域前置知识）
│   ├── cmos-fundamentals.md                 CMOS 工艺基础：NMOS/PMOS、静态逻辑门、功耗、工艺缩放
│   ├── number-systems.md                    数字的数制表示：二进制、补码、定点数、浮点数、格雷码
│   ├── metastability.md                     亚稳态：物理机理、MTBF 公式、同步器设计
│   └── semiconductor-basics.md              半导体基础：能带、掺杂、PN 结、MOSFET、PVT 变异
│
├── rtl-design/                              ← RTL 设计领域
│   ├── rtl-design_MOC.md                    领域入口：概念索引与相关领域链接
│   └── concepts/
│       ├── verilog-hdl.md                   Verilog HDL：IEEE 1364、模块/端口、wire/reg、阻塞/非阻塞赋值
│       ├── systemverilog.md                 SystemVerilog：always_ff/comb/latch、logic、interface、DPI
│       ├── combinational-logic.md           组合逻辑：always @(*) vs assign、锁存器陷阱、毛刺与冒险
│       ├── sequential-logic.md              时序逻辑：D-FF、setup/hold、同步/异步复位、门控时钟
│       ├── fsm-design.md                    有限状态机：Moore/Mealy、三段式编码、状态编码策略
│       ├── pipeline-design.md               RTL 流水线设计：吞吐率/延迟权衡、stall/flush、反压
│       ├── cdc-cross-domain.md              RTL 跨时钟域：2-FF 同步器、异步 FIFO、握手同步
│       ├── arithmetic-circuits.md           算术电路：RCA/CLA/CSA、Booth 乘法器、Wallace Tree
│       └── coding-style.md                  RTL 编码风格：命名规范、可综合清单、Lint 规则、CDC 实践
│
├── verification/                            ← 功能验证领域
│   ├── verification_MOC.md                  领域入口：验证方法论与工具索引
│   └── concepts/
│       ├── uvm-methodology.md               UVM 方法学：类库层次、工厂机制、Phase、TLM、RAL
│       ├── systemverilog-assertions.md      SVA：即时/并发断言、property、蕴含算子、bind
│       ├── coverage-model.md                覆盖率模型：代码覆盖 vs 功能覆盖、covergroup/cross
│       ├── constrained-random.md            约束随机验证：rand/randc、constraint、分布约束
│       ├── formal-verification.md           形式验证：属性检查、等价性检查、BMC
│       └── testbench-architecture.md        验证平台架构：分层 testbench、agent/scoreboard
│
├── architecture/                            ← 计算机体系结构领域
│   ├── architecture_MOC.md                  领域入口：处理器架构概念索引
│   └── concepts/
│       ├── pipelining.md                    指令流水线：五级流水、数据冒险/转发、控制冒险
│       ├── out-of-order.md                  乱序执行：Tomasulo 算法、寄存器重命名、ROB
│       ├── branch-prediction.md             分支预测：BHT、GSHARE、TAGE、BTB、RAS
│       ├── cache-coherence.md               缓存一致性：MSI/MESI/MOESI、snooping vs directory
│       ├── memory-hierarchy.md              存储层次：Cache 组织、TLB、替换策略、预取
│       ├── on-chip-bus.md                   片上总线：AXI4/AXI5 五通道、CHI 协议、NoC
│       └── soc-architecture.md              SoC 架构：异构多核、Die-to-Die、chiplet、安全
│
├── asic-flow/                               ← ASIC 实现流程领域
│   ├── asic-flow_MOC.md                     领域入口：RTL→GDSII 全流程索引
│   └── concepts/
│       ├── synthesis.md                     逻辑综合：三阶段、SDC 约束、技术映射、物理感知综合
│       ├── static-timing-analysis.md        STA：setup/hold 检查、时钟定义、MCMM、时序路径
│       ├── dft.md                           可测性设计：Scan Chain、ATPG、MBIST/LBIST、JTAG
│       ├── clock-tree.md                    时钟树综合：H-tree/CTS、Useful Skew、CCD
│       ├── place-and-route.md               布局布线：Floorplan、Place、CTS insert、Route、ECO
│       ├── power-analysis.md                功耗分析：动态/静态功耗、Clock/Power Gating、DVFS
│       ├── signoff.md                       Signoff：时序签核、IR Drop、EM、LEC
│       └── physical-verification.md         物理验证：DRC、LVS、ERC、Antenna、DFM
│
└── cross-domain/                            ← 跨领域交叉概念
    ├── timing-closure.md                    时序收敛：RTL→Signoff 迭代闭环、OCV→LVF 演进
    ├── low-power-design.md                  低功耗设计：UPF、Power Domain、Multi-Vth、AVS
    ├── clock-domain-crossing.md             跨时钟域（CDC）全貌：MTBF、同步器、CDC 验证
    └── reset-methodology.md                  复位策略：同步 vs 异步复位、Reset Tree、复位域
```

## 文件统计

| 类别 | 数量 |
|:---|:---|
| 入口与规则 | 3（数字IC_入口.md, CLAUDE.md, README.md） |
| 基础概念 | 4 |
| RTL 设计 | 1 MOC + 9 概念 |
| 功能验证 | 1 MOC + 6 概念 |
| 体系结构 | 1 MOC + 7 概念 |
| ASIC 流程 | 1 MOC + 8 概念 |
| 跨领域 | 4 |
| **合计** | **~46 文件** |

## 元数据类型

| type | 用途 | 示例 |
|:---|:---|:---|
| `index` | Vault 级别入口 | `数字IC_入口.md` |
| `moc` | 领域内容地图 | `rtl-design_MOC.md` |
| `concept` | 核心概念笔记 | 所有 `concepts/` 下的文件 |
| `spec` | 项目规范与规则 | `CLAUDE.md` |

## 关联知识库

- **3GPP LTE/NR 译码链路**（`~/AGENT/obsidian/3gpp/`）——独立 vault，通信基带协议与算法

## 维护说明

- 新增概念：放在对应领域的 `concepts/` 下，文件名小写 kebab-case
- 新增领域：创建 `<name>/<name>_MOC.md` + `concepts/` 子目录
- 跨领域概念：放在 `cross-domain/` 下
- 文件规范：参见 `CLAUDE.md`
