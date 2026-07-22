---
type: concept
aliases:
  - Physical Verification
  - 物理验证
  - PV
  - DRC
  - LVS
tags:
  - asic
  - asic-flow
  - physical-verification
  - drc
  - lvs
source_spec: "Mentor Calibre User Guide, Cadence PVS/Pegasus User Guide, Synopsys IC Validator User Guide, Baker CMOS Design Rules"
---

# 物理验证（Physical Verification）

物理验证（Physical Verification, PV）是确保版图（Layout/GDSII）在物理层面可被晶圆厂可靠制造的最后一道技术关卡。物理验证不合格的版图即使时序完美也无法被可靠制造——DRC 违例意味着晶圆厂的光刻/刻蚀/CMP 工艺会产生制造缺陷；LVS 不匹配意味着版图中的晶体管连接与原始网表不一致。与 STA 验证时序、LEC 验证逻辑不同，PV 关注版图几何结构与制造规则的符合性。物理验证使用专用的签核级 EDA 工具：Mentor Calibre（市场份额最高）、Cadence PVS/Pegasus、Synopsys IC Validator，这些工具将设计规则手册（Design Rule Manual, DRM）编码为可执行规则检查脚本（Rule Deck），对 GDSII/OASIS 版图文件进行全面逐层几何分析。

## 原理

### 设计规则检查（DRC）

设计规则检查（Design Rule Check, DRC）验证版图几何图形是否符合晶圆厂 DRM 中定义的所有强制性制造规则。核心规则类别包括：

**间距规则（Spacing）**：同层或不同层间最小间距——间距过小导致光刻后金属桥接短路。以 FinFET 为例，M1 最小间距可从 64nm（16nm 节点）缩至 32nm（7nm 节点）。**宽度规则（Width）**：每层金属/多晶硅/扩散区最小宽度——宽度过小导致断路（Open）或过高的互连线电阻使 IR 压降恶化。

**面积规则（Area）**：每层金属最小面积——面积过小在化学机械抛光（Chemical Mechanical Polishing, CMP）过程中可能被完全磨掉（Dishing Effect），导致对应金属岛完全消失。**通孔包围规则（Via Enclosure/Extension）**：通孔必须被上下层金属充分包围——包围不足导致接触电阻增加或完全开路。以 7nm 为例，Mx 对 Vx 的单边最小包围为 5-8nm。

**密度规则（Density）**：全局和局部金属密度必须在规定范围内（如 25%-65%）——密度过低导致 CMP 过度抛光（Dishing），密度过高导致 CMP 抛光不足（Oxide Erosion）。密度违反通过金属填充（Metal Fill/Dummy Fill）自动修复——工具在空闲区域插入不连接任何信号的地/VDD 参考的"哑金属"片。

**阱/有源区规则（Well/OD Rules）**：N 阱到 P 阱的最小间距（防止闩锁效应 Latch-up）、有源区最小宽度和间距（影响晶体管驱动强度和 SEU 敏感性）。DRC 是计算密集型的几何处理问题——现代芯片版图包含数十亿个多边形，层次化验证（Hierarchical DRC，利用单元的重复性缩小检查范围）和并行分布式计算（将版图分块分配给多个 CPU）是可行性的关键。

### 版图与原理图一致性检查（LVS）

版图与原理图一致性检查（Layout vs. Schematic, LVS）验证版图中的实际晶体管级连接是否与原理图网表完全一致。LVS 流程分为三个阶段：

**器件识别（Device Recognition）**：LVS 规则文件定义了如何从版图的几何图形（晶体管有源区、多晶硅栅、通孔触点）组合中识别出晶体管、电阻、电容和二极管等器件类型。例如，识别一个 NMOS 晶体管需要检测多晶硅栅与 N+ 有源区相交区域形成的沟道。

**网络提取（Net Extraction）**：将所有互连金属、通孔和接触孔组成的连续导电区域提取为网络（Net），并为每个网络赋予一个唯一编号或名称。网络提取是 LVS 中最关键的计算步骤——需要处理 GDSII 中的非曼哈顿几何（任意角度走线）和层次化冲突。

**比较（Comparison）**：将版图提取的器件和网络图与原理图网表中的器件和网络图进行图同构匹配（Graph Isomorphism）。同构指的是两图的节点（器件）和边（网络连接）之间存在一一对应的双射映射关系。不匹配报告包括：多余/缺失器件、短路/断路网络、端口不匹配等。LVS 比较结果需要设计者仔细分析并确认——许多不匹配是由于命名不一致（如原理图命名为 `clk_buf_1`，版图自动提取为 `net_12345`）或等价节点（版图中通过金属直接短路的多个电源引脚，原理图中为不同端口）导致的假不匹配。LVS 通常与寄生参数提取（Parasitic Extraction, PEX）联动——PEX 在 LVS 识别出的网络基础上计算各线网的 RC 寄生参数，输出 SPEF 文件供 STA 反标。

### 电气规则检查（ERC）

电气规则检查（Electrical Rule Check, ERC）在版图层面检查可能导致电路故障或可靠性问题的电气条件：

**阱连接检查（Well Tie Check）**：N 阱必须连接到 VDD，P 衬底必须连接到 VSS——浮动阱（Floating Well）可能导致闩锁效应或异常的衬底偏置调制，改变晶体管阈值电压。**浮栅检测（Floating Gate Check）**：晶体管的栅极不能通过高阻路径连接到其他网络——浮栅会累积电荷使晶体管处于不确定状态，在辐射环境中尤其严重。

**天线规则检查（Antenna Rule Check）**：检查金属互联在等离子刻蚀过程中积累的电荷是否可能击穿相连的薄栅氧化层。在制造过程中，长金属线作为"天线"收集等离子体电荷，当金属线与晶体管栅极连接的总面积（Antenna Ratio = Metal Area / Gate Area）超过工艺规定的天线比（如 400:1）时，电荷积累的电压可能击穿栅氧化层。天线修复通过在长金属线上插入"天线二极管"（Antenna Diode）——将金属线连接到扩散区，提供电荷泄放路径。

**器件参数检查**：验证关键器件的 W/L 比、电阻值、电容值是否在设计范围内，特别是在模拟/混合信号 IP 中。

### 可制造性设计（DFM）验证

先进节点中，仅满足 DRC 规则已不足以保证高成品率——需要额外的可制造性设计（Design for Manufacturability, DFM）规则来提升工艺窗口。

**推荐规则（Recommended Rules）**：比 DRC 强制规则更宽松的"灰区规则"——如使用比最小宽度宽 10%-20% 的金属线可提高成品率，但会略微增加面积。DFM 规则修复通常在 DRC Clean 之后，作为成品率优化的非强制步骤。

**通孔倍增（Via Doubling/Double Via）**：将单通孔连接替换为双通孔或更多通孔的冗余连接——如果一个通孔在制造中失效，另一个通孔仍能保持连接。通孔是制造失效概率最高的结构，冗余通孔可将通孔相关成品率损失降低 50%-90%。

**CMP 平坦度分析**：分析版图的层间介质厚度均匀性——金属密度分布不均导致 CMP 后表面高低起伏（Topography Variation），影响上层光刻聚焦精度。DFM 工具使用 CMP 模型仿真各层抛光后的表面轮廓，指导金属填充（Dummy Fill）的密度分布优化以改善平坦度。

**光刻热点检测（Lithography Hotspot Detection）**：使用光刻仿真（OPC Model）预测版图中容易产生光刻缺陷（如颈缩、桥接）的图形——这些几何图形虽然通过 DRC 但是在光刻工艺窗口边缘，工艺波动时易导致缺陷。现代 DFM 工具（如 Calibre LFD, Litho-Friendly Design）使用全芯片光刻仿真检测热点，并以热点密度指标（Hotspot Density per mm²）衡量版图的光刻友好程度。

## 关键要点

- DRC 是几何规则检查（宽度/间距/面积/包围/密度），违反制造规则直接导致功能或可靠性缺陷——DRC 是 Tape-Out 的绝对前提
- LVS 验证版图晶体管级连接与原理图网表的全等性——器件识别（Device Recognition）和网络提取（Net Extraction）是 LVS 的技术核心
- 天线规则（Antenna Rule）保护栅氧化层不受等离子工艺的电荷损伤——天线比（Metal Area / Gate Area）超过阈值需插入天线二极管泄放电荷
- 阱连接（Well Tie）和浮栅（Floating Gate）是 ERC 的核心检查项——浮动阱导致闩锁，浮栅导致不确定的晶体管状态
- 密度规则（Density 25%-65%）确保 CMP 平坦度，通过金属填充（Dummy Fill）自动修复——填充金属不连接任何功能信号
- DFM 规则（通孔倍增、CMP 平坦度、光刻热点）超越基本 DRC 以提升成品率——在先进节点中 DFM 检查已成为 Tape-Out 强制项
- 层次化 DRC/LVS（Hierarchical Verification）利用单元的重复性压缩检查范围——是处理数十亿多边形的核心效率手段
- Calibre 是物理验证的事实标准，支持 DRC/LVS/ERC/DFM 统一规则平台，代工厂（Foundry）直接提供 Calibre Rule Deck

## 与其他概念的关系

- [[asic-flow/concepts/signoff|签核（Signoff）]] — 物理验证（DRC/LVS/ERC）是 Signoff 流程中的强制检查项，未通过物理验证的门级网表不能投片（Tape-Out）
- [[asic-flow/concepts/place-and-route|布局布线（P&R）]] — P&R 输出的 GDSII 版图是 DRC/LVS 的输入来源，P&R 中的 DFM 感知布线（如自动通孔倍增）减少后续 DFM 修复迭代
- [[asic-flow/concepts/static-timing-analysis|静态时序分析（STA）]] — LVS 通过后的寄生参数提取（PEX/SPEF）提供精确互连线 RC 延迟反标，是 Signoff STA 使用真实互连线延迟的前提
- [[asic-flow/concepts/power-analysis|功耗分析（Power Analysis）]] — IR Drop 分析需要 LVS 确认的供电网络提取结果——LVS 网络不匹配会导致 IR 分析供电拓扑错误
