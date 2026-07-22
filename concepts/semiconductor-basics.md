---
type: concept
aliases:
  - 半导体基础
  - Semiconductor Physics
  - Band Theory
  - Doping
  - PN Junction
  - MOSFET
  - Short-Channel Effects
  - PVT Variation
tags:
  - asic
  - concepts
  - semiconductor
  - device-physics
  - mosfet
  - cmos
source_spec: "Pierret, Semiconductor Device Fundamentals; Sze & Ng, Physics of Semiconductor Devices; Taur & Ning, Fundamentals of Modern VLSI Devices"
---

# 半导体基础（Semiconductor Physics Fundamentals）

半导体物理是数字集成电路的底层科学——从单个晶体管的开关行为，到工艺角变异（Process Corner Variation），再到先进工艺的短沟道效应和量子限制效应，无不根植于半导体材料的能带结构和载流子输运机制。对于数字IC设计师而言，理解半导体基础不是为了设计晶体管本身，而是为了理解晶体管行为的边界条件——为什么电压降低后速度变慢、为什么温度升高漏电加剧、为什么工艺偏差导致不同芯片的速度差异——从而在架构和 RTL 层面做出正确的设计决策。

## 原理

### 能带理论与掺杂

半导体材料的导电性由其能带结构决定。在纯净（本征）半导体（如硅 Si）中，价带（Valence Band）被电子填满，导带（Conduction Band）空置，两者之间的禁带（Bandgap，硅在 300K 下约 1.12 eV）使得电子在室温下难以获得足够的能量跃迁到导带——本征半导体的导电性极弱。通过**掺杂（Doping）**——有意地在硅晶格中引入杂质原子——可以精确控制导电性：N 型掺杂引入五价元素（磷 P、砷 As），多余的价电子在禁带中形成施主能级（Donor Level），仅需极少的热能即可跃迁到导带，成为自由电子；P 型掺杂引入三价元素（硼 B），缺少的价电子形成受主能级（Acceptor Level），从价带捕获电子，留下空穴（Hole）——空穴在外电场下可移动，等效于正电荷载流子。

掺杂浓度决定半导体的电阻率。数字IC的标准 MOSFET 沟道就是通过选择性掺杂（离子注入，Ion Implantation）在硅衬底上精确制造的 N 型和 P 型区域。源漏（Source/Drain）区域重掺杂（浓度约 10^20 cm^-3），导电性接近金属；沟道区域的掺杂浓度决定了晶体管的阈值电压（Vth）。

### PN 结

PN 结是半导体器件最基本的结谊。当 P 型半导体与 N 型半导体接触时，交界面附近的高浓度梯度驱动载流子扩散——空穴从 P 区扩散到 N 区，电子从 N 区扩散到 P 区——留下不可移动的电离杂质原子（P 区留下负的受主离子，N 区留下正的施主离子），在交界面形成空间电荷区（Space Charge Region / Depletion Region）。空间电荷产生的内建电场（Built-in Electric Field）方向从 N 指向 P，恰好阻止进一步的净扩散流动，形成动态平衡。内建电势（Built-in Potential）的大小由掺杂浓度和温度决定：

$$\phi_{bi} = \frac{kT}{q} \ln\left(\frac{N_A N_D}{n_i^2}\right)$$

其中 k 为玻尔兹曼常数，T 为绝对温度，q 为电子电荷，N_A/N_D 为受主/施主浓度，n_i 为本征载流子浓度。

PN 结具有单向导电性（整流特性）：正向偏置（P 端电压高于 N 端）时耗尽区变窄、势垒降低，大量载流子跨越结面形成正向电流——电流随正向电压指数增长；反向偏置（P 端电压低于 N 端）时耗尽区变宽、势垒升高，只有极小的反向饱和电流流过。MOSFET 的源-衬底和漏-衬底就是两个 PN 结，正常工作时处于反向偏置状态——这也是为什么体效应（Body Effect）会影响阈值电压。

### MOSFET 结构与工作原理

金属-氧化物-半导体场效应晶体管（MOSFET）是现代数字IC的基本开关元件，由四个端子组成：栅极（Gate, G）、源极（Source, S）、漏极（Drain, D）和体/衬底（Body/Bulk, B）。以 NMOS 为例：在 P 型衬底上制作两个 N+ 区域作为源极和漏极，源漏之间是沟道区，上方覆盖一层极薄的绝缘层（栅氧化层，Gate Oxide，早期为 SiO2，先进工艺为高 k 材料如 HfO2），再上方是导电的栅极（早期为多晶硅 Poly-Si，先进工艺为金属栅 Metal Gate）。

当栅极对源极的电压 Vgs 超过阈值电压 Vth 时，栅极的正电荷通过电容效应在 P 型衬底表面排斥空穴、吸引电子，形成一层极薄的导电沟道——反型层（Inversion Layer）——连接源极和漏极。此时若在漏极和源极之间施加正电压 Vds，电子从源极经沟道流向漏极，形成漏极电流 Id。在 Vds 较小时，Id 与 Vds 近似线性（线性区/三极管区）；当 Vds 增大到 Vgs - Vth 时，漏极端的沟道被夹断（Pinch-Off），Id 趋于饱和（饱和区），近似由栅压控制。

PMOS 的工作原理与 NMOS 对称但极性相反：N 型衬底、P+ 源漏、负的 Vgs 吸引空穴形成沟道。这就是 CMOS 技术中互补对称的来源。

**增强型（Enhancement-Mode）vs 耗尽型（Depletion-Mode）**：增强型 MOSFET 在 Vgs = 0 时没有导电沟道（正常情况下截止），需要施加栅压来创建沟道——数字 IC 中几乎所有 MOSFET 都是增强型。耗尽型 MOSFET 在 Vgs = 0 时已有导电沟道（通过沟道注入预先掺杂），栅压用来关闭沟道——在数字 IC 中较少使用，但在模拟电路和某些特殊数字单元中有应用。

### 阈值电压与体效应

阈值电压（Threshold Voltage, Vth）定义为在栅极下方形成导电沟道所需的最小栅源电压。Vth 取决于栅氧化层厚度（t_ox）、沟道掺杂浓度以及栅材料的功函数（Work Function）。氧化层越薄，栅极对沟道的静电控制越强，Vth 越低——这正是工艺缩放中持续减薄氧化层的驱动力之一。但氧化层减薄到 1-2 nm 级别后，栅极隧道漏电急剧增大，成为先进工艺中的主要漏电来源之一，促使了高 k 介质+金属栅（HKMG）技术的引入。

体效应（Body Effect / Substrate Bias Effect）描述衬底偏压对 Vth 的影响。当源极和衬底不短接时（实际 NMOS 的衬底接 GND，源极可能高于 GND），源-衬底 PN 结的反向偏压增大，耗尽区展宽，沟道电荷减少，Vth 升高。体效应可以量化为：

$$\Delta V_{th} = \gamma \left( \sqrt{2\phi_F + V_{SB}} - \sqrt{2\phi_F} \right)$$

其中 γ 是体效应系数，V_SB 是源-衬底电压，φ_F 是费米势。在堆叠晶体管（如 NAND 门中的串联 NMOS）中，非最底端的晶体管源极不接衬底电压（浮空），体效应使其 Vth 更高、驱动能力更弱——这是为什么 NAND 门的串联 NMOS 尺寸通常比单个 NMOS 大。

### 亚阈值导电与 PVT 变异

亚阈值导电（Subthreshold Conduction / Subthreshold Leakage）指 Vgs < Vth 时仍有微弱电流流过沟道——电流随 Vgs 指数衰减，在室温下每降低约 60-80 mV（亚阈值斜摆，Subthreshold Swing / SS），漏电降低一个数量级。理论极限 SS = (kT/q) * ln(10) ≈ 60 mV/decade，先进 FinFET 器件已非常接近这一极限。亚阈值漏电是先进工艺中静态功耗的主要来源——当几百万个晶体管每个都有皮安级漏电时，芯片级静态功耗可达数瓦。

PVT 变异（Process/Voltage/Temperature Variation）是数字IC设计中必须面对的物理现实：
- **工艺变异（P）**：晶圆与晶圆之间（Wafer-to-Wafer）、芯片与芯片之间（Die-to-Die, D2D）、以及芯片内（Within-Die, WID / On-Chip Variation, OCV）的晶体管参数偏差，来自光刻精度、掺杂均匀度、氧化层厚度公差和 CMP 平整度等制造步骤的随机性和系统性误差。
- **电压变异（V）**：供电电压在芯片不同位置的静态 IR-drop 和动态 di/dt 电压跌落。
- **温度变异（T）**：芯片不同区域因功耗密度差异而形成温度梯度（Thermal Gradient）。温度影响载流子迁移率（温度升高 → 迁移率降低 → 速度变慢）和 Vth（温度升高 → Vth 降低 → 速度变快），两者的净效果决定了 "温度反转" 效应——在某些工艺节点和电压条件下，晶体管在高温下反而比低温更快。这一现象直接影响了时序 Signoff 工艺角的选择策略。

### 短沟道效应

随着沟道长度缩小到深亚微米级别，出现了若干传统长沟道模型中不存在的非理想效应，统称为短沟道效应（Short-Channel Effects, SCE）：

**漏致势垒降低（Drain-Induced Barrier Lowering, DIBL）**：漏极的高电压通过耗尽区穿透沟道，降低了源极端的电子势垒，使得 Vth 随 Vds 升高而降低——沟道越短，DIBL 越严重。DIBL 破坏了理想 MOSFET 中 Id 在饱和区的独立于 Vds 的特性，使输出阻抗降低。

**速度饱和（Velocity Saturation）**：在高电场下，载流子的漂移速度不再随电场线性增长，而是趋于饱和速度（硅中电子约 10^7 cm/s）。短沟道中即使 Vds 不大，沟道内的电场也已极高——载流子极早期就进入速度饱和，导致 Id 远低于长沟道模型预测值，且饱和区的 Id 与 Vgs 变为近似线性关系而非平方关系。

**热载流子效应（Hot Carrier Effects）**：沟道中的高能载流子（"热载流子"）可能获得足够能量穿透到栅氧化层中，或产生碰撞电离（Impact Ionization）生成额外的电子-空穴对，长期作用下导致 Vth 漂移和可靠性退化（热载流子注入 HCI 老化）。

这些短沟道效应是 FinFET、GAA 等 3D 晶体管结构取代平面 MOSFET 的根本驱动力——立体沟道结构大大增强了栅极对沟道的静电控制（Gate Electrostatics），抑制了 DIBL 和亚阈值漏电。

## 关键要点

- 能带理论解释半导体导电性的根源：掺杂（N 型/P 型）在禁带中引入施主/受主能级，精确控制载流子浓度和类型
- PN 结是半导体器件的核心结构：内建电场和单向导电性决定了 MOSFET 源漏与衬底之间的隔离特性
- MOSFET 通过栅极电场在衬底表面形成反型层导电沟道——栅氧化层厚度和沟道掺杂决定 Vth
- 增强型 MOSFET（Vgs=0 时截止）是数字IC的主流选择，因为零静态功耗的开关行为
- 体效应使串联堆叠的晶体管中上端晶体管的 Vth 升高，影响 NAND/NOR 门的尺寸设计
- 亚阈值导电（SS ≈ 60-90 mV/decade）是先进工艺静态功耗的核心来源，决定了 Multi-Vth 策略的物理基础
- PVT 变异是 STA 和时序收敛必须处理的物理现实——工艺角（SS/FF/TT/SF/FS）是对 PVT 极端条件的工程抽象
- 短沟道效应（DIBL、速度饱和、HCI）推动了 FinFET 和 GAA 等 3D 晶体管结构的诞生

## 与其他概念的关系

- [[concepts/cmos-fundamentals|CMOS 基础]] — MOSFET 在数字电路中的应用：CMOS 反相器、NAND/NOR 门、静态功耗和动态功耗的物理起源
- [[concepts/metastability|亚稳态（Metastability）]] — 亚稳态解析时间常数 τ 取决于晶体管的 gm 和节点电容，是器件物理参数在数字可靠性中的直接体现
- [[cross-domain/low-power-design|低功耗设计]] — 亚阈值漏电、体偏置、Multi-Vth 和速度-漏电权衡的器件物理基础
- [[cross-domain/timing-closure|时序收敛]] — PVT 变异和工艺角的物理来源决定了 STA 必须在多个 Corner 下进行分析
