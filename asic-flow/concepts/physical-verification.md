---
type: concept
aliases:
  - Physical Verification
  - 物理验证
  - PV
tags:
  - asic
  - asic-flow
  - physical-verification
  - drc
  - lvs
source_spec: "Mentor Calibre User Guide, Synopsys ICV User Guide, Cadence PVS User Guide, Foundry Design Rule Manuals (DRM)"
---

# 物理验证（Physical Verification）

物理验证（Physical Verification, PV）是确保版图（Layout / GDSII）在物理层面可被晶圆厂制造的最后一道技术关卡。物理验证不合格的版图即使时序完美也无法被可靠制造。与 STA 验证时序、LEC 验证逻辑不同，PV 关注版图几何结构与制造规则的符合性——即设计的物理表示是否可被光刻、刻蚀、沉积和 CMP 等工艺步骤精确加工出来。

## 原理

### 设计规则检查

设计规则检查（Design Rule Check, DRC）验证版图几何图形是否符合晶圆厂设计规则手册（DRM）中定义的所有强制性规则。核心规则类别包括：间距规则（Spacing）——同层或不同层间最小间距，间距过小导致光刻桥接短路；宽度规则（Width）——每层金属/多晶硅/扩散区最小宽度，宽度过小导致断路或过高电阻；面积规则（Area）——每层金属最小面积，面积过小在 CMP 过程中可能被完全磨掉（Dishing）；包围规则（Enclosure/Extension）——通孔必须被上下层金属充分包围，不足导致高阻连接或开路；密度规则（Density）——全局和局部金属密度必须在规定范围内（如 25%-65%），过低导致 CMP 过度抛光，过高导致抛光不足。密度违反通过金属填充（Metal Fill / Dummy Fill）修复。DRC 是计算密集型的几何处理问题——现代芯片版图包含数十亿个多边形，层次化验证（Hierarchical Verification）和并行分布式计算是可行性的关键。

### 版图与原理图一致性检查

版图与原理图一致性检查（Layout vs Schematic, LVS）验证从版图中提取的晶体管级网表（Extracted Netlist）与设计的黄金网表（Golden Netlist）在拓扑结构和器件参数上完全一致。LVS 回答两个核心问题：**器件一一对应（Device Matching）**——版图中的每个 MOS 晶体管是否在 Golden Netlist 中找到对应器件，参数（W、L、M）是否匹配；**连接关系一致（Connectivity Matching）**——版图中各器件端口的连接关系是否与 Golden Netlist 完全一致，是否存在开路（Open）或意外短路（Short）。

LVS 核心技术步骤：器件识别（Device Recognition）——从扩散层（Diffusion/Active）与多晶硅（Poly）的交叠区域识别 NMOS/PMOS；连接提取（Connectivity Extraction）——追踪金属和多晶硅/扩散层之间的通孔连接关系，建立节点图和器件端口映射；图同构比对（Graph Isomorphism Comparison）——将版图提取网表和 Golden Netlist 都表示为图结构（节点=网络、边=器件），运行图同构算法检查拓扑等价。

### 电气规则检查

电气规则检查（Electrical Rule Check, ERC）验证版图的电气特性是否满足可靠性要求。**天线规则（Antenna Rule / PAE：Process Antenna Effect）**是最关键的 ERC 检查——在等离子刻蚀和离子注入工艺中，悬空长金属或多晶硅走线充当"天线"，收集带电离子在 MOSFET 栅极上积累电荷导致栅氧层击穿。天线比率（金属面积/栅极面积）必须小于工艺限定值。修复方法包括跳层（通过通孔将长走线切换到另一层金属，使天线面积"重置"）和插入天线二极管（提供电荷泄放通路）。

**阱接触规则（Well TAP / Substrate Contact）**要求 N-Well 接 $V_{DD}$、P-Substrate 接 GND——防闩锁效应（Latch-up）。**浮空栅极检测**确保所有栅极都有可驱动来源。

### DFM 与密度填充

可制造性设计（Design for Manufacturability, DFM）超越基本 DRC 的 Pass/Fail 模式，使用光刻仿真模型（OPC 模型）识别可能产生桥接或断路的弱图案——光刻热点检查（Lithography Hotspot Detection）。CMP 热点检查识别厚度不一致的密度分布模式。**关键面积分析（Critical Area Analysis, CAA）**根据版图几何和缺陷尺寸分布，分析特定位置缺陷导致短路或断路的概率。补充 DFM 措施还包括：过孔加倍（Redundant Vias）提升良率，扩散走线避免最小宽度的长平行线，缺口/间隙填充检查。

Signoff 级 PV 使用晶圆厂认证的签核工具——业界 Gold Standard 为 Siemens/Mentor **Calibre** nmDRC/nmLVS 套件，层次化引擎能处理亿级至十亿级多边形的全芯片 DRC/LVS。Cadence **PVS**（Physical Verification System）和 Synopsys **ICV**（IC Validator）提供与各自 P&R 工具的紧密集成，减少数据转换开销。

## 关键要点

- DRC 验证数十亿个多边形与数千条制造规则的符合性——层次化和并行处理是可行性的关键
- LVS 验证版图与网表的拓扑等价：器件一一对应（类型 + 参数匹配）+ 连接完全一致（无开路/无短路）
- 天线规则保护栅氧层不被工艺等离子体损坏——跳层和天线二极管是两种标准修复方法
- 密度规则（如 25%-65% 局部金属密度）对 CMP 均匀性至关重要——通过插入 Dummy Fill 修复
- ERC 检查阱接触、浮空栅极和 latch-up 预防规则——忽略这些规则可能导致正常工作中闩锁烧毁
- DFM 超越 DRC 的 Pass/Fail 模式，提供光刻仿真、CMP 仿真和 CAA 等量化指标主动指导版图改进
- Calibre 是 PV 的行业 Gold Standard，层次化引擎能处理亿级至十亿级多边形的全芯片 DRC/LVS
- 物理验证是 Tape-Out 前的"最后一关"——时序/功耗/PV/LEC 全部 GREEN 才能释放 GDSII 给晶圆厂

## 与其他概念的关系

- [[asic-flow/concepts/place-and-route|布局布线（P&R）]] — P&R 输出的 GDSII 是 PV 的输入，DRC/LVS 发现的违例需返回 P&R 做 ECO 修复
- [[asic-flow/concepts/signoff|签核（Signoff）]] — PV 是签核四大维度之一（时序/功耗/PV/LEC），全部通过才能 Tape-Out
- [[asic-flow/concepts/synthesis|逻辑综合（Synthesis）]] — LVS 使用的 Golden Netlist 源自综合和 P&R 输出的门级网表、DFT 插入后的网表
- [[concepts/cmos-fundamentals|CMOS 基础]] — DRC 规则的物理依据是 CMOS 制造限制（光刻分辨率、刻蚀偏差、CMP 平坦度）
