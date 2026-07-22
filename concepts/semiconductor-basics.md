---
type: concept
aliases:
  - 半导体基础
  - Semiconductor Physics
  - Band Theory
  - PN Junction
  - MOSFET
tags:
  - asic
  - basics
  - semiconductor
  - cmos
source_spec: "Pierret, Semiconductor Device Fundamentals; Sze & Ng, Physics of Semiconductor Devices; Taur & Ning, Fundamentals of Modern VLSI Devices"
---

# 半导体基础（Semiconductor Physics Fundamentals）

半导体物理是数字集成电路的底层科学——从单个晶体管的开关行为，到 PVT 变异，再到先进工艺的短沟道效应，无不根植于半导体材料的能带结构和载流子输运机制。对于数字 IC 设计师而言，理解半导体基础是为了理解晶体管行为的边界条件——从而在架构和 RTL 层面做出正确设计决策。

## 原理

### 能带理论与掺杂

半导体材料的导电性由能带结构决定。在纯净硅中，价带（Valence Band）被电子填满，导带（Conduction Band）空置，两者之间禁带（Bandgap，硅在 300K 下 $E_g \approx 1.12\text{ eV}$）使电子在室温下难以跃迁。导体（无禁带）、绝缘体（$E_g > 5\text{ eV}$）、半导体（小禁带，可控导电）由此区分。

通过**掺杂（Doping）**精确控制导电性：N 型掺杂引入五价元素（磷 P、砷 As）——多余价电子形成施主能级（Donor Level），仅需极少热能即可跃迁到导带成为自由电子，留下固定正离子；P 型掺杂引入三价元素（硼 B）——缺少价电子形成受主能级（Acceptor Level），从价带捕获电子留下空穴（Hole），空穴在外电场下可移动等效于正电荷载流子。数字 IC 的 MOSFET 沟道通过离子注入在硅衬底上精确制造 N 型和 P 型区域——源漏重掺杂（约 $10^{20}\text{ cm}^{-3}$），沟道掺杂浓度决定 $V_{th}$。

### PN 结

PN 结是半导体器件最基本的结构。P 型与 N 型半导体接触时，浓度梯度驱动载流子扩散——空穴从 P 到 N，电子从 N 到 P——留下不可移动的电离杂质原子，形成空间电荷区（Space Charge Region / Depletion Region）。空间电荷产生的内建电场方向从 N 指向 P，阻止进一步净扩散，形成动态平衡。内建电势：

$$\phi_{bi} = \frac{kT}{q} \ln\left(\frac{N_A N_D}{n_i^2}\right) \approx 0.7\text{ V}$$

PN 结具有单向导电性（整流特性）：正向偏置时耗尽区变窄、势垒降低，电流随正向电压指数增长；反向偏置时耗尽区变宽，仅极小反向饱和电流流过。MOSFET 的源-衬底和漏-衬底就是两个反向偏置 PN 结——这也是体效应影响 $V_{th}$ 的原因。

### MOSFET 结构与工作原理

MOSFET 由四个端子组成：栅极（Gate）、源极（Source）、漏极（Drain）、体/衬底（Body/Bulk）。以 NMOS 为例：P 型衬底上制作两个 N+ 区域作为源漏，上方覆盖极薄栅氧化层（$SiO_2$ 或高 K 材料 $HfO_2$），再上方为导电栅极（多晶硅或金属栅）。当 $V_{GS} > V_{th}$ 时，栅极正电荷通过电容效应在衬底表面排斥空穴、吸引电子，形成极薄导电沟道——反型层（Inversion Layer）——连接源漏。$V_{DS}$ 较小时 $I_D$ 近似线性（线性区）；$V_{DS}$ 增至 $V_{GS} - V_{th}$ 时漏极沟道夹断（Pinch-Off），$I_D$ 趋于饱和。PMOS 对称但极性相反。**增强型（Enhancement-Mode）**——$V_{GS} = 0$ 时截止，需栅压创建沟道——是数字 IC 主流；耗尽型（Depletion-Mode）仅在特殊场合使用。

### 阈值电压与体效应

$V_{th}$ 取决于栅氧化层厚度 $t_{ox}$（越薄 $V_{th}$ 越低，但栅极漏电剧增驱动 HKMG 引入）、沟道掺杂浓度以及栅材料功函数。体效应（Body Effect / Substrate Bias Effect）描述衬底偏压对 $V_{th}$ 的影响：源-衬底反向偏压增大时，耗尽区展宽、沟道电荷减少、$V_{th}$ 升高：

$$\Delta V_{th} = \gamma \left( \sqrt{2\phi_F + V_{SB}} - \sqrt{2\phi_F} \right)$$

在堆叠晶体管（如 NAND 门中的串联 NMOS）中，非最底端晶体管源极浮空，体效应使 $V_{th}$ 更高、驱动能力更弱——NAND 门串联 NMOS 尺寸需加大的物理原因。

### 亚阈值导电与 PVT 变异

亚阈值导电（Subthreshold Conduction）指 $V_{GS} < V_{th}$ 时仍有微弱电流——电流随 $V_{GS}$ 指数衰减，室温下约 60-80 mV 降低一个数量级（亚阈值斜摆 SS）。理论极限 $SS = (kT/q) \cdot \ln(10) \approx 60\text{ mV/decade}$。亚阈值漏电是先进工艺静态功耗的主要来源——百万晶体管 × 皮安级漏电 = 瓦级芯片静态功耗。

PVT 变异是数字 IC 设计必须面对的物理现实：Process（晶圆间/芯片间/芯片内晶体管参数偏差——光刻精度、掺杂均匀度、$t_{ox}$ 公差和 CMP 平整度）；Voltage（静态 IR-Drop 和动态 $di/dt$ 电压跌落）；Temperature（影响迁移率（升温变慢）和 $V_{th}$（升温降低变快）——两者净效果导致"温度反转"效应，直接决定 Signoff 角选择）。工艺角（SS/FF/TT/SF/FS）是对 PVT 极端条件的工程抽象。

### 短沟道效应

随着沟道长度缩小到深亚微米级别，出现三个关键非理想效应：**漏致势垒降低（DIBL: Drain-Induced Barrier Lowering）**——漏极高电压通过耗尽区穿透沟道降低源极电子势垒，$V_{th}$ 随 $V_{DS}$ 升高而降低；**速度饱和（Velocity Saturation）**——高电场下载流子漂移速度趋于饱和（硅中电子约 $10^7\text{ cm/s}$），短沟道中 $I_D$ 远低于长沟道预测；**热载流子效应（Hot Carrier Effects）**——高能载流子穿透栅氧化层或产生碰撞电离，长期导致 $V_{th}$ 漂移和 HCI 老化。这些效应是 FinFET、GAA 等 3D 晶体管结构取代平面 MOSFET 的根本驱动力——立体沟道增强栅极静电控制，抑制 DIBL 和亚阈值漏电。

## 关键要点

- 能带理论：导体（无禁带）、绝缘体（$E_g > 5\text{ eV}$）、半导体（$E_g \approx 1.12\text{ eV}$）——掺杂在禁带中引入施主/受主能级精确控制导电性
- PN 结内建电场 $\phi_{bi} \approx 0.7\text{ V}$ 和单向导电性决定 MOSFET 源漏与衬底的隔离特性
- MOSFET 通过栅极电场在衬底表面形成反型层导电沟道——$t_{ox}$ 和沟道掺杂决定 $V_{th}$
- 体效应使串联堆叠中上端晶体管 $V_{th}$ 升高——NAND 门串联 NMOS 尺寸需加大的物理原因
- 亚阈值导电 SS $\approx$ 60-80 mV/decade 是先进工艺静态功耗核心来源，决定 Multi-Vth 策略的物理基础
- PVT 变异是 STA 和时序收敛必须处理的物理现实——工艺角（SS/FF/TT/SF/FS）是对极端条件的工程抽象
- 短沟道效应（DIBL、速度饱和、HCI）推动 FinFET 和 GAA 等 3D 晶体管结构的诞生

## 与其他概念的关系

- [[concepts/cmos-fundamentals|CMOS 基础]] — MOSFET 在数字电路中的应用：CMOS 反相器、NAND/NOR 门、静态/动态功耗的物理起源
- [[concepts/metastability|亚稳态（Metastability）]] — 亚稳态解析时间常数 $\tau$ 取决于晶体管 $g_m$ 和节点电容，器件物理在数字可靠性中的直接体现
- [[cross-domain/low-power-design|低功耗设计]] — 亚阈值漏电、Multi-Vth 和漏电-速度权衡的器件物理基础
- [[cross-domain/timing-closure|时序收敛]] — PVT 变异和工艺角的物理来源决定 STA 必须在多个 Corner 下进行分析
