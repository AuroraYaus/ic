---
type: concept
aliases:
  - 组合逻辑
  - Combinational Logic
  - 门级逻辑
  - 无记忆电路
tags:
  - asic
  - rtl
  - combinational
  - digital-logic
source_spec: "Wakerly, Digital Design: Principles and Practices; Palnitkar, Verilog HDL; IEEE 1800-2017"
---

# 组合逻辑（Combinational Logic）

组合逻辑是数字电路的两大基本类型之一（另一类是时序逻辑）。组合逻辑电路的输出仅取决于当前输入值，不依赖任何历史状态——它没有记忆能力，也没有反馈回路。任何数字系统都可以分解为组合逻辑（Cloud of Combinational Logic）和时序元件（Registers）的交替结构，这是同步时序电路设计的核心抽象。从最简单的与门、多路选择器到复杂的 ALU（算术逻辑单元）、译码器和优先级编码器，组合逻辑是数字 IC 设计者每天都必须面对的基本构件。

## 原理

### 从真值表到门级实现

组合逻辑的设计始于真值表（Truth Table）和逻辑函数。任意 n 输入的布尔函数有 2^n 种输入组合，每个组合对应一个确定的输出值，可用真值表唯一描述。从真值表推导组合电路有两条经典路径：**积之和（Sum of Products, SOP）** 形式通过两级与-或（AND-OR）结构实现——首先用与门覆盖真值表中输出为 1 的所有"质蕴含项（Prime Implicants）"，再用或门聚合输出；**和之积（Product of Sums, POS）** 形式通过两级或-与（OR-AND）结构实现。逻辑最小化（Logic Minimization）的目标是在满足时序约束的前提下，用最少的门和最短的关键路径实现目标布尔函数。现代 EDA 综合工具（如 Synopsys Design Compiler、Cadence Genus）使用代数化简和布尔优化算法（如 Espresso 两电平化简器）结合技术映射（Technology Mapping），将 RTL 描述的布尔函数映射到标准单元库中的具体门级电路。

### RTL 编码方式：assign 与 always_comb

在 RTL 中描述组合逻辑有两种主要方式：

**连续赋值（Continuous Assignment）**：使用 `assign` 关键字，右侧表达式的任何输入变化立即反映到左侧输出。适用于单方程描述的简单组合逻辑，如 `assign sum = a ^ b ^ cin;`。assign 语句描述的电路是纯组合逻辑，不存在锁存器推断风险。

**always_comb 块**：使用 SystemVerilog 的 `always_comb` 关键字（Verilog 中为 `always @(*)`），块内可以使用 if-else、case、for 等过程化控制流结构。always_comb 的编译时检查（灵敏度列表完整性、零时刻执行、禁止自身赋值）使其比传统 `always @(*)` 更安全。always_comb 块中**必须使用阻塞赋值（`=`，Blocking Assignment）**——阻塞赋值在仿真时按顺序立即执行，在组合逻辑中语义正确。若误用非阻塞赋值（`<=`），仿真时会在时间步末尾才更新信号，导致组合逻辑输出延迟一拍——这是典型的仿真与综合不匹配（Simulation-Synthesis Mismatch）错误。

### 锁存器推断：RTL 编码的常见陷阱

组合逻辑 RTL 编码中最危险的陷阱是**意外锁存器推断（Unintended Latch Inference）**。当 always_comb（或 always @(*)）块中存在未在所有条件下赋值的变量时，综合工具推断出锁存器（Latch）来"记住"该变量的旧值。典型场景：
- if 语句缺少 else 分支，且 if 分支中赋值的信号在 else 路径上未赋值
- case 语句缺少 default 分支，且并非所有 case 项覆盖了信号的赋值

锁存器对 ASIC 设计是严格的 lint 违规项，原因有三：锁存器是电平敏感的异步元件，STA（静态时序分析）难以准确建模其时序行为；锁存器在 DFT（可测试性设计）扫描链中不可控，降低故障覆盖率；锁存器对工艺偏差敏感，可能产生毛刺（Glitch）。避免锁存器推断的铁律：**组合 always 块中，每个被赋值的信号必须在所有控制路径上都有赋值**——即 if 必须配 else，case 必须配 default。

### 毛刺与竞争

组合逻辑信号经过不同延迟路径到达同一点时，会产生**毛刺（Glitch）**——短暂的错误脉冲输出。毛刺分为三类：
- **静态 0 毛刺（Static-0 Hazard）**：输出应保持 0，但出现了短时的 1→0→1 脉冲
- **静态 1 毛刺（Static-1 Hazard）**：输出应保持 1，但出现了短时的 1→0→1 脉冲
- **动态毛刺（Dynamic Hazard）**：输出应为 0→1（或 1→0）的单次翻转，但出现了多次翻转

毛刺的根源是组合逻辑路径中不同支路的传播延迟（Propagation Delay）不同（竞争条件 Race Condition）。消除毛刺的方法有三种：使用冗余质蕴含项覆盖毛刺产生的相邻输入组合（卡诺图消除法），这是静态毛刺的数学上彻底的解决方案；在组合逻辑输出后加 D 触发器采样的**寄存器输出**（最大毛刺消除与同步设计兼容）；使用格雷码（Gray Code）编码使状态变化只有一个比特翻转，从根本上消除多比特同时变化的竞争源。在同步时序设计中，毛刺通常不是功能性问题——只要在建立时间窗口内信号稳定，触发器的正确采样不受影响——但毛刺会增加动态功耗（无意义的信号跳变），在异步接口（如 CDC 边界）中则可能导致功能错误。

## 关键要点

- 组合逻辑输出仅取决于当前输入，无记忆、无反馈；always_comb 块中必须使用阻塞赋值（`=`）
- 锁存器推断是组合逻辑 RTL 编码的头号陷阱：if 必须配 else，case 必须配 default，所有被赋值的信号在所有路径上都必须有明确赋值
- assign 连续赋值永远不会产生锁存器推断，是单方程组合逻辑的首选编写方式
- 毛刺由不同延迟路径的竞争产生，同步时序设计中毛刺通常被寄存器滤除，但异步边界需要格雷码等额外保护
- 两级 S-O-P 实现（与或阵列）在布线延迟较大时，第三级或更复杂的 AOI/OAI 复合门可同时减少面积和延迟
- 组合逻辑的关键路径延迟等于从输入到输出的最长累积门延迟，与时钟周期直接相关
- 多路选择器（MUX）是组合逻辑的通用实现基元：任何 n 变量布尔函数都可以用 2^n:1 MUX 和反相器实现
- 综合工具的代数化简（Espresso、BDD）会自动处理 SOP 最小化，设计者应关注代码级别而非门级别的面积优化
- 组合逻辑的 glitch 功率（Glitch Power）在深亚微米工艺中可能占据动态功耗的 20%-30%，使用流水线寄存器隔离可显著降低
- `unique case` 和 `priority case` 声明了 case 项之间的互斥/优先级关系，综合工具据此优化并插入违反断言

## 与其他概念的关系

- [[rtl-design/concepts/verilog-hdl|Verilog HDL]] — Verilog 中 assign 连续赋值和 always @(*) 进程块描述组合逻辑的语法与语义陷阱
- [[rtl-design/concepts/systemverilog|SystemVerilog]] — SV 的 always_comb 提供编译时锁存器推断检查和自动灵敏度列表推断
- [[rtl-design/concepts/sequential-logic|时序逻辑]] — 组合逻辑是时序逻辑的核心组成部分（Cloud of Combinational Logic），与触发器交替构成同步电路
- [[rtl-design/concepts/coding-style|RTL 编码风格]] — 组合逻辑编码规范：锁存器推断检查，阻塞赋值/非阻塞赋值的使用规则
